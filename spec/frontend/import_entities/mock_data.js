const mockLicensedFeatureAvailability = (available) => ({
  available,
  __typename: 'LicensedFeatureAvailability',
});

export const mockGroupFactory = (fullPath, available = true) => ({
  id: `gid://gitlab/Group/${fullPath}`,
  fullPath,
  name: fullPath,
  projectCreationLevel: 'maintainer',
  visibility: 'public',
  webUrl: `http://gdk.test:3000/groups/${fullPath}`,
  licensedFeatureAvailability: mockLicensedFeatureAvailability(available),
  __typename: 'Group',
});

export const mockAvailableNamespaces = [
  mockGroupFactory('match1'),
  mockGroupFactory('unrelated'),
  mockGroupFactory('match2'),
  mockGroupFactory('sortme'),
  mockGroupFactory('sortmea'),
  mockGroupFactory('sortmeaa'),
  mockGroupFactory('sortmeab'),
];

export const mockNamespacesResponse = {
  data: {
    currentUser: {
      id: 'gid://gitlab/User/1',
      groups: {
        nodes: mockAvailableNamespaces,
        __typename: 'GroupConnection',
      },
      namespace: {
        id: 'gid://gitlab/Namespaces::UserNamespace/1',
        fullPath: 'root',
        licensedFeatureAvailability: mockLicensedFeatureAvailability(true),
        __typename: 'Namespace',
      },
      __typename: 'UserCore',
    },
  },
};

export const mockUserNamespace = 'user1';
