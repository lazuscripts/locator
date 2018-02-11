{
  {
    path: "applications.users" -- there is a sub-application at this location relative to the repository's root
    migrations: {after: 1518414112} -- don't run any migrations earlier than this one
  }
  {
    path: "utility" -- another sub-application is here
  }
}
