class ApiConfig {
  static const String baseUrl = "https://tm.davidab.ro/api/v1";
  static const String tasks = '$baseUrl/tasks';
  static const String messages = '$baseUrl/messages';
  static const String workspaces = '$baseUrl/workspaces';

  static String workspaceMessages(String workspaceId) => '$messages/workspace/$workspaceId';
  static String workspaceTasks(String workspaceId) => '$tasks/workspace/$workspaceId';
}
