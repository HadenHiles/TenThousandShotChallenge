import 'package:flutter/material.dart';

class BasicTextField extends StatefulWidget {
  BasicTextField({Key key, this.hintText, this.controller, this.validator})
      : super(key: key);

  final String hintText;
  final TextEditingController controller;
  final Function validator;

  @override
  _BasicTextFieldState createState() => _BasicTextFieldState();
}

class _BasicTextFieldState extends State<BasicTextField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Theme.of(context).textTheme.bodyText1.color,
      style: Theme.of(context).textTheme.bodyText1,
      decoration: InputDecoration(
        hintStyle: Theme.of(context).textTheme.bodyText1,
        hintText: widget.hintText,
      ),
      controller: widget.controller,
      validator: widget.validator,
    );
  }
}
