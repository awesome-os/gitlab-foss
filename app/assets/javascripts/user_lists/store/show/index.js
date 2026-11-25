import { defineStore } from 'pinia';
import Api from '~/api';
import { HTTP_STATUS_TOO_MANY_REQUESTS } from '~/lib/utils/http_status';
import { states } from '../../constants/show';
import { parseUserIds, stringifyUserIds } from '../utils';

const savedUserIds = (userList) =>
  userList?.user_xids?.length > 0 ? parseUserIds(userList.user_xids) : [];

export const useUserListShow = defineStore('userListShow', {
  state() {
    return {
      state: states.LOADING,
      projectId: '',
      userListIid: '',
      userIds: [],
      userList: null,
      errorMessage: '',
    };
  },
  actions: {
    setInitialData({ projectId, userListIid }) {
      this.projectId = projectId;
      this.userListIid = userListIid;
    },
    receiveSuccess(data) {
      this.state = states.SUCCESS;
      this.userIds = savedUserIds(data);
      this.userList = data;
    },
    async fetchUserList() {
      this.state = states.LOADING;
      try {
        const response = await Api.fetchFeatureFlagUserList(this.projectId, this.userListIid);
        this.receiveSuccess(response.data);
      } catch {
        this.state = states.ERROR;
      }
    },
    dismissErrorAlert() {
      this.state = states.ERROR_DISMISSED;
    },
    addUserIds(userIds) {
      this.userIds = [
        ...this.userIds,
        ...parseUserIds(userIds).filter((id) => id && !this.userIds.includes(id)),
      ];
      return this.updateUserList();
    },
    removeUserId(userId) {
      this.userIds = this.userIds.filter((uid) => uid !== userId);
      return this.updateUserList();
    },
    async updateUserList() {
      this.state = states.LOADING;

      try {
        const response = await Api.updateFeatureFlagUserList(this.projectId, {
          ...this.userList,
          user_xids: stringifyUserIds(this.userIds),
        });
        this.receiveSuccess(response.data);
      } catch (error) {
        // The add or remove changed userIds before the request, so we restore the saved list
        this.userIds = savedUserIds(this.userList);
        this.errorMessage =
          error?.response?.status === HTTP_STATUS_TOO_MANY_REQUESTS
            ? (error.response.data?.message?.error ?? '')
            : '';
        this.state = states.ERROR;
      }
    },
  },
});
