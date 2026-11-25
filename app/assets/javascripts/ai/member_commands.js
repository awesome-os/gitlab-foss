import { FLOW_TRIGGER_EVENTS } from '~/vue_shared/constants';
import { demoteCurrentUser, prioritizeMentionedMembers } from '~/lib/utils/autocomplete_mentions';
import { userIsDisabled } from './agents_utils';

/* eslint-disable @gitlab/no-hardcoded-urls -- quick action command strings, not URLs */
export const MEMBER_COMMAND = {
  ASSIGN: '/assign',
  REASSIGN: '/reassign',
  UNASSIGN: '/unassign',
  ASSIGN_REVIEWER: '/assign_reviewer',
  REVIEWER: '/reviewer',
  REQUEST_REVIEW: '/request_review',
  REASSIGN_REVIEWER: '/reassign_reviewer',
  UNASSIGN_REVIEWER: '/unassign_reviewer',
  REMOVE_REVIEWER: '/remove_reviewer',
};
/* eslint-enable @gitlab/no-hardcoded-urls */

const ASSIGNEES = 'assignees';
const REVIEWERS = 'reviewers';

// `flowTriggerEvent` hides agents that can't act on the command. Removal commands have none,
// so everyone who holds the role stays listed. `role` with `current` keeps only members who
// hold (true) or don't hold (false) that role.
const RULES = {
  [MEMBER_COMMAND.ASSIGN]: {
    flowTriggerEvent: FLOW_TRIGGER_EVENTS.ASSIGN,
    role: ASSIGNEES,
    current: false,
  },
  [MEMBER_COMMAND.REASSIGN]: { flowTriggerEvent: FLOW_TRIGGER_EVENTS.ASSIGN },
  [MEMBER_COMMAND.UNASSIGN]: { role: ASSIGNEES, current: true },
  // Current reviewers stay listed, so a review can be requested from them again.
  [MEMBER_COMMAND.ASSIGN_REVIEWER]: { flowTriggerEvent: FLOW_TRIGGER_EVENTS.ASSIGN_REVIEWER },
  [MEMBER_COMMAND.REVIEWER]: { flowTriggerEvent: FLOW_TRIGGER_EVENTS.ASSIGN_REVIEWER },
  [MEMBER_COMMAND.REQUEST_REVIEW]: { flowTriggerEvent: FLOW_TRIGGER_EVENTS.ASSIGN_REVIEWER },
  [MEMBER_COMMAND.REASSIGN_REVIEWER]: { flowTriggerEvent: FLOW_TRIGGER_EVENTS.ASSIGN_REVIEWER },
  [MEMBER_COMMAND.UNASSIGN_REVIEWER]: { role: REVIEWERS, current: true },
  [MEMBER_COMMAND.REMOVE_REVIEWER]: { role: REVIEWERS, current: true },
};

const MENTION_RULE = { flowTriggerEvent: FLOW_TRIGGER_EVENTS.MENTION };

export const isMemberCommand = (command) => Object.hasOwn(RULES, command);

const toUsernameSet = (users) => new Set(users.map((username) => username.toLowerCase()));

/**
 * Filters and orders the `@` suggestions that follow a quick action, or a plain mention.
 *
 * @param {Array<{username: String}>} members - Candidates, already sorted by how well they match the query.
 * @param {Object} options
 * @param {String} [options.command] - The quick action before the `@`, if any.
 * @param {String[]} [options.assignees] - Usernames currently assigned.
 * @param {String[]} [options.reviewers] - Usernames currently reviewing.
 * @param {String[]} [options.mentioned] - Usernames mentioned in the editor, in order of appearance.
 * @param {Function} [options.tierOf] - Match tier of a member; the current user is demoted within it.
 * @returns {Array} The members to list, in order.
 */
export function membersForCommand(
  members,
  { command, assignees = [], reviewers = [], mentioned = [], tierOf } = {},
) {
  const rule = RULES[command] ?? MENTION_RULE;
  const holders = rule.role && toUsernameSet(rule.role === ASSIGNEES ? assignees : reviewers);

  const filtered = members.filter((member) => {
    if (rule.flowTriggerEvent && userIsDisabled(member, rule.flowTriggerEvent)) return false;
    if (!holders) return true;

    return holders.has(member?.username?.toLowerCase()) === rule.current;
  });

  if (!isMemberCommand(command)) return demoteCurrentUser(filtered, tierOf);

  return prioritizeMentionedMembers(filtered, mentioned);
}
