import 'package:flutter/material.dart';
import 'skeleton_loading_widget.dart';


class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Modern skeleton loading that mimics the actual UI structure
    return SkeletonLoadingWidget(
      itemCount: 6, // Show 6 skeleton friend items
    );
  }
}