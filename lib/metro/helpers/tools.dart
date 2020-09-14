/// Helper used to capitalize a [String] value
String capitalize(String input) {
  if (input == null) {
    throw new ArgumentError("string: $input");
  }
  if (input.length == 0) {
    return input;
  }
  return input[0].toUpperCase() + input.substring(1);
}
