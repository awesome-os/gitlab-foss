import { cloneDeep } from 'lodash-es';
import MockAdapter from 'axios-mock-adapter';
import { roleDropdownItems } from '~/members/utils';
import {
  getRoleDropdownItems,
  getMemberRole,
  callRoleUpdateApi,
  setMemberRole,
} from '~/members/components/table/drawer/utils';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { member as memberMock } from '../../../mock_data';

const getRoles = (member) => roleDropdownItems(member).flatten;

describe('Role details drawer utils', () => {
  describe('getRoleDropdownItems', () => {
    it('returns dropdown items', () => {
      expect(getRoleDropdownItems).toBe(roleDropdownItems);
    });
  });

  describe('getMemberRole', () => {
    const roles = getRoles(memberMock);

    it.each(roles)('returns $text role for member', (expectedRole) => {
      const member = cloneDeep(memberMock);
      member.accessLevel.integerValue = expectedRole.accessLevel;
      const role = getMemberRole(roles, member);

      expect(role).toBe(expectedRole);
    });

    it('returns the role data of the member when the role is not in the list', () => {
      const maintainerRoles = roles.filter(({ accessLevel }) => accessLevel < 50);
      const role = getMemberRole(maintainerRoles, memberMock);

      expect(role).toEqual({ text: 'Owner', value: 50 });
    });

    it('returns the role data of the member when there are no roles', () => {
      const role = getMemberRole(getRoles({ validRoles: {} }), memberMock);

      expect(role).toEqual({ text: 'Owner', value: 50 });
    });

    it('keeps the member role ID of the member in the role data', () => {
      const member = cloneDeep(memberMock);
      member.accessLevel.memberRoleId = 101;
      const role = getMemberRole([], member);

      expect(role).toEqual({ text: 'Owner', value: 50, memberRoleId: 101 });
    });
  });

  describe('callRoleUpdateApi', () => {
    it.each`
      namespace          | propertyName
      ${'user'}          | ${'access_level'}
      ${'group'}         | ${'group_access'}
      ${'accessRequest'} | ${'access_level'}
      ${'directMembers'} | ${'access_level'}
    `(
      'calls update API with expected data for each member.namespace = $namespace',
      async ({ namespace, propertyName }) => {
        const memberPath = 'member/path/123';
        const mockAxios = new MockAdapter(axios);
        mockAxios.onPut(memberPath).replyOnce(HTTP_STATUS_OK);

        const member = { ...memberMock, memberPath, namespace };
        const role = getRoles(member)[1];
        await callRoleUpdateApi(member, role);

        expect(mockAxios.history.put).toHaveLength(1);
        expect(mockAxios.history.put[0].data).toBe(
          JSON.stringify({ [propertyName]: 10, member_role_id: null }),
        );
      },
    );
  });

  describe('setMemberRole', () => {
    const roles = getRoles(memberMock);

    it.each(roles)('updates member access level for role $text', (role) => {
      const member = cloneDeep(memberMock);
      setMemberRole(member, role);

      expect(member.accessLevel).toEqual({
        stringValue: role.text,
        integerValue: role.accessLevel,
        description: role.description,
        memberRoleId: role.memberRoleId,
      });
    });
  });
});
