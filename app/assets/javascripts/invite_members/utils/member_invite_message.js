import { n__, s__, sprintf } from '~/locale';
import { MEMBER_INVITE_MESSAGE_SUCCESSFUL } from '../constants';

export function memberInviteSuccessMessage({ addedCount = 0, invitedCount = 0 }) {
  if (addedCount > 0 && invitedCount > 0) {
    const added = n__(
      'InviteMembersModal|%d member was added.',
      'InviteMembersModal|%d members were added.',
      addedCount,
    );
    const invited = n__(
      'InviteMembersModal|%d invitation was sent.',
      'InviteMembersModal|%d invitations were sent.',
      invitedCount,
    );

    return sprintf(s__('InviteMembersModal|%{added} %{invited}'), { added, invited });
  }

  if (invitedCount > 0) {
    return n__(
      "InviteMembersModal|Invitation sent. We'll let you know when they join.",
      "InviteMembersModal|Invitations sent. We'll let you know when they join.",
      invitedCount,
    );
  }

  return MEMBER_INVITE_MESSAGE_SUCCESSFUL;
}
