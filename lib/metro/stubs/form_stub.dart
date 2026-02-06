import 'package:recase/recase.dart';

/// This stub is used to create NyFormWidget.
String formStub(ReCase className) => '''
import 'package:nylo_framework/nylo_framework.dart';

/* ${className.pascalCase} Form
|--------------------------------------------------------------------------
| Usage: https://nylo.dev/docs/7.x/forms#how-it-works
| Casts: https://nylo.dev/docs/7.x/forms#form-casts
| Validation Rules: https://nylo.dev/docs/7.x/validation#validation-rules
|-------------------------------------------------------------------------- */

class ${className.pascalCase}Form extends NyFormWidget {

  ${className.pascalCase}Form({super.key, super.submitButton, super.onSubmit, super.onFailure});

  // @override
  // get init => () {
  //   /// Initial data for the form
  //   return {
  //     "name": "Anthony",
  //     "price": "100",
  //     "favourite_color": "Blue",
  //     "bio": "I am a Flutter Developer"
  //   };
  // };

  @override
  fields() => [
    Field.text("Name"),
    [
      Field.currency("Price",
        currency: "usd",
        dummyData: "19.99",
      ),
      Field.picker("Favourite Color",
        options: FormCollection.fromArray([
          "Red",
          "Blue",
          "Green"
        ]),
        validator: FormValidator.contains(["Red","Blue","Green"]),
      ),
    ],
    Field.textArea("Bio"),
  ];

  static NyFormActions get actions => const NyFormActions('${className.pascalCase}Form');
}
''';
