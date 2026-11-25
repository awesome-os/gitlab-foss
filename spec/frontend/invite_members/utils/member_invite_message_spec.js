import { memberInviteSuccessMessage } from '~/invite_members/utils/member_invite_message';

describe('memberInviteSuccessMessage', () => {
  it.each`
    addedCount | invitedCount | expected
    ${2}       | ${0}         | ${'Members were successfully added.'}
    ${0}       | ${1}         | ${"Invitation sent. We'll let you know when they join."}
    ${0}       | ${3}         | ${"Invitations sent. We'll let you know when they join."}
    ${1}       | ${1}         | ${'1 member was added. 1 invitation was sent.'}
    ${2}       | ${3}         | ${'2 members were added. 3 invitations were sent.'}
  `(
    'returns "$expected" for $addedCount added and $invitedCount invited',
    ({ addedCount, invitedCount, expected }) => {
      expect(memberInviteSuccessMessage({ addedCount, invitedCount })).toBe(expected);
    },
  );
});
