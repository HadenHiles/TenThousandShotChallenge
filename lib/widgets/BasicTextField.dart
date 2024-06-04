import 'package:flutter/material.dart';

class BasicTextField extends StatefulWidget {
  const BasicTextField({super.key, this.hintText, this.initialValue, this.controller, this.keyboardType, this.validator});

  final String? hintText;
  final String? initialValue;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Function? validator;

  @override
  State<BasicTextField> createState() => _BasicTextFieldState();
}

class _BasicTextFieldState extends State<BasicTextField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Theme.of(context).textTheme.bodyLarge!.color,
      style: Theme.of(context).textTheme.bodyLarge,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        hintStyle: Theme.of(context).textTheme.bodyLarge,
        hintText: widget.hintText,
      ),
      initialValue: widget.initialValue,
      controller: widget.controller,
      validator: widget.validator as String? Function(String?)?,
    );
  }
}
