import { setCurrentUser } from 'helpers/current_user_helper';
import { MEMBER_COMMAND, isMemberCommand, membersForCommand } from '~/ai/member_commands';

const agent = (username, flowTriggerEvents, extra = {}) => ({
  username,
  compositeIdentityEnforced: true,
  flowTriggerEvents,
  ...extra,
});

const MEMBERS = {
  user: { username: 'user' },
  mention: agent('mention_agent', ['MENTION']),
  assign: agent('assign_agent', ['ASSIGN']),
  reviewer: agent('reviewer_agent', ['ASSIGN_REVIEWER']),
  untriggered: agent('untriggered_agent', []),
  outOfCredits: agent('out_of_credits_agent', ['MENTION', 'ASSIGN', 'ASSIGN_REVIEWER'], {
    disabled: true,
  }),
};
const ALL = Object.keys(MEMBERS);
const members = Object.values(MEMBERS);
const usernames = members.map(({ username }) => username);
const namesOf = (results) =>
  results.map((result) => Object.keys(MEMBERS).find((key) => MEMBERS[key] === result));

describe('ai/member_commands', () => {
  describe('isMemberCommand', () => {
    it.each(Object.values(MEMBER_COMMAND))('is true for %s', (command) => {
      expect(isMemberCommand(command)).toBe(true);
    });

    it.each(['/label', '/assignee', '', undefined])('is false for %s', (command) => {
      expect(isMemberCommand(command)).toBe(false);
    });
  });

  describe('membersForCommand', () => {
    describe('filtering', () => {
      // Which members are listed when nobody holds a role, when everyone is
      // assigned, and when everyone is reviewing.
      it.each`
        command                 | none                    | assigned                | reviewing
        ${undefined}            | ${['user', 'mention']}  | ${['user', 'mention']}  | ${['user', 'mention']}
        ${'/label'}             | ${['user', 'mention']}  | ${['user', 'mention']}  | ${['user', 'mention']}
        ${'/assign'}            | ${['user', 'assign']}   | ${[]}                   | ${['user', 'assign']}
        ${'/reassign'}          | ${['user', 'assign']}   | ${['user', 'assign']}   | ${['user', 'assign']}
        ${'/unassign'}          | ${[]}                   | ${ALL}                  | ${[]}
        ${'/assign_reviewer'}   | ${['user', 'reviewer']} | ${['user', 'reviewer']} | ${['user', 'reviewer']}
        ${'/reviewer'}          | ${['user', 'reviewer']} | ${['user', 'reviewer']} | ${['user', 'reviewer']}
        ${'/request_review'}    | ${['user', 'reviewer']} | ${['user', 'reviewer']} | ${['user', 'reviewer']}
        ${'/reassign_reviewer'} | ${['user', 'reviewer']} | ${['user', 'reviewer']} | ${['user', 'reviewer']}
        ${'/unassign_reviewer'} | ${[]}                   | ${[]}                   | ${ALL}
        ${'/remove_reviewer'}   | ${[]}                   | ${[]}                   | ${ALL}
      `('for $command', ({ command, none, assigned, reviewing }) => {
        const listed = (roles) => namesOf(membersForCommand(members, { command, ...roles }));

        expect(listed({})).toEqual(none);
        expect(listed({ assignees: usernames })).toEqual(assigned);
        expect(listed({ reviewers: usernames })).toEqual(reviewing);
      });
    });

    it('matches assignees and reviewers whatever the username case', () => {
      const results = membersForCommand(members, {
        command: MEMBER_COMMAND.UNASSIGN,
        assignees: ['USER'],
      });

      expect(namesOf(results)).toEqual(['user']);
    });

    it('reads agent attributes in snake case, as the rich text editor receives them', () => {
      const snakeCaseAgent = {
        username: 'snake_agent',
        composite_identity_enforced: true,
        flow_trigger_events: ['ASSIGN'],
      };

      expect(membersForCommand([snakeCaseAgent], { command: MEMBER_COMMAND.ASSIGN })).toEqual([
        snakeCaseAgent,
      ]);
      expect(membersForCommand([snakeCaseAgent], { command: undefined })).toEqual([]);
    });

    describe('ordering', () => {
      const alice = { username: 'alice' };
      const bob = { username: 'bob' };
      const carol = { username: 'carol' };
      const people = [alice, bob, carol];

      it.each(Object.values(MEMBER_COMMAND))(
        'floats mentioned members to the top in mention order for %s',
        (command) => {
          // Removal commands list only who holds the role.
          const everyone = ['alice', 'bob', 'carol'];
          const roles = {
            [MEMBER_COMMAND.UNASSIGN]: { assignees: everyone },
            [MEMBER_COMMAND.UNASSIGN_REVIEWER]: { reviewers: everyone },
            [MEMBER_COMMAND.REMOVE_REVIEWER]: { reviewers: everyone },
          }[command];

          expect(
            membersForCommand(people, { command, ...roles, mentioned: ['carol', 'bob'] }),
          ).toEqual([carol, bob, alice]);
        },
      );

      it('keeps the signed-in user in place for member commands', () => {
        setCurrentUser({ username: 'alice' });

        expect(membersForCommand(people, { command: MEMBER_COMMAND.REASSIGN })).toEqual(people);
      });

      describe('for a plain mention', () => {
        beforeEach(() => {
          setCurrentUser({ username: 'alice' });
        });

        it('does not float mentioned members', () => {
          expect(membersForCommand(people, { mentioned: ['carol'] })).toEqual([bob, carol, alice]);
        });

        it('lists the signed-in user last within their match tier', () => {
          const tierOf = (member) => (member === carol ? 1 : 0);

          expect(membersForCommand(people, { tierOf })).toEqual([bob, alice, carol]);
        });
      });
    });
  });
});
