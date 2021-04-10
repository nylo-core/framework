class RouteNotFoundError extends Error {
  final String name;

  RouteNotFoundError({
    required this.name,
  });

  @override
  String toString() {
    return "** Route '$name' not found! Make sure you are not using the wrong name"
        " or have registered the route.";
  }
}
