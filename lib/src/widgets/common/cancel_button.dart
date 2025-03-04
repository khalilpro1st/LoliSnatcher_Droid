import 'package:flutter/material.dart';

class CancelButton extends StatelessWidget {
  const CancelButton({
    Key? key,
    this.text = 'Cancel',
    this.returnData,
    this.withIcon = false,
  }) : super(key: key);

  final String text;
  final dynamic returnData;
  final bool withIcon;

  @override
  Widget build(BuildContext context) {
    if (withIcon) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          primary: Colors.grey[300],
          onPrimary: Colors.black,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        onPressed: () {
          Navigator.of(context).pop(returnData);
        },
        icon: Icon(withIcon ? Icons.cancel_outlined : null),
        label: Text(text),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        primary: Colors.grey[300],
        onPrimary: Colors.black,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      onPressed: () {
        Navigator.of(context).pop(returnData);
      },
      child: Text(text),
    );
  }
}
