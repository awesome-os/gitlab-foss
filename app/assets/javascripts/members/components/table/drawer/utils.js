import axios from '~/lib/utils/axios_utils';
import { roleDropdownItems, initialSelectedRole } from '~/members/utils';
import {
  GROUP_LINK_ACCESS_LEVEL_PROPERTY_NAME,
  MEMBER_ACCESS_LEVEL_PROPERTY_NAME,
  MEMBERS_TAB_TYPES,
} from '~/members/constants';

// EE overrides these.
export const getRoleDropdownItems = roleDropdownItems;

export const getMemberRole = (roles, member) => {
  const { stringValue, integerValue, memberRoleId } = member.accessLevel;
  const role = initialSelectedRole(roles, member);
  // The roles are the ones the current user can assign. The member's role is not always one of them, for example an
  // Owner seen by a Maintainer, or any project member seen by a logged out user, so fall back to the member's role data.
  return role || { text: stringValue, value: integerValue, memberRoleId };
};

// The API to update members uses different property names for the access level, depending on each member's namespace
const ACCESS_LEVEL_PROPERTY_NAME = {
  [MEMBERS_TAB_TYPES.user]: MEMBER_ACCESS_LEVEL_PROPERTY_NAME,
  [MEMBERS_TAB_TYPES.group]: GROUP_LINK_ACCESS_LEVEL_PROPERTY_NAME,
  [MEMBERS_TAB_TYPES.accessRequest]: MEMBER_ACCESS_LEVEL_PROPERTY_NAME,
  [MEMBERS_TAB_TYPES.directMembers]: MEMBER_ACCESS_LEVEL_PROPERTY_NAME,
};

export const callRoleUpdateApi = async (member, role) => {
  const accessLevelProp = ACCESS_LEVEL_PROPERTY_NAME[member.namespace];

  return axios.put(member.memberPath, {
    [accessLevelProp]: role.accessLevel,
    member_role_id: role.memberRoleId || null,
  });
};

export const setMemberRole = (member, role) => {
  // eslint-disable-next-line no-param-reassign
  member.accessLevel = {
    stringValue: role.text,
    integerValue: role.accessLevel,
    description: role.description,
    memberRoleId: role.memberRoleId,
  };
};
