import 'dart:developer';

String capitalize(String input) {
  if (input == null) {
    throw new ArgumentError("string: $input");
  }
  if (input.length == 0) {
    return input;
  }
  return input[0].toUpperCase() + input.substring(1);
}

class NyLogger {

  NyLogger addLn(String str) {
    log(str);
    return this;
  }
}