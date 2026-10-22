// CalseeTextField: text input on a themed face.
//
// The text uses the theme's key font in the face's label colour, and the
// theme's focus ring shows while the field has focus. It takes the usual
// EditableText options: controller, keyboard type, input formatters.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class TextFieldExample extends StatefulWidget {
  const TextFieldExample({super.key});

  @override
  State<TextFieldExample> createState() => _TextFieldExampleState();
}

class _TextFieldExampleState extends State<TextFieldExample> {
  String _name = '';
  String _note = '';

  @override
  Widget build(BuildContext context) {
    final colors = CalseeTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalseeTextField(
            hint: 'Name or UPI ID',
            textInputAction: TextInputAction.next,
            onChanged: (value) => setState(() => _name = value),
          ),
          const SizedBox(height: 12),
          CalseeTextField(
            hint: 'Add a note',
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            onChanged: (value) => setState(() => _note = value),
          ),
          const SizedBox(height: 16),
          Text(
            _name.isEmpty
                ? 'Type above to see it here.'
                : 'Paying $_name${_note.isEmpty ? '' : ' for "$_note"'}',
            style: TextStyle(color: colors.secondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
