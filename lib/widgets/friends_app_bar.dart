import 'package:flutter/material.dart';

class FriendsAppBar extends StatelessWidget {
  final AnimationController gradientController;

  const FriendsAppBar({
    Key? key,
    required this.gradientController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 50,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final top = constraints.biggest.height;
          final isCollapsed = top <= kToolbarHeight + MediaQuery.of(context).padding.top;

          return AnimatedBuilder(
            animation: gradientController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorTween(
                        begin: Colors.blue.shade600,
                        end: Colors.blue.shade800,
                      ).animate(gradientController).value!,
                      ColorTween(
                        begin: Colors.blue.shade800,
                        end: Colors.blue.shade600,
                      ).animate(gradientController).value!,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(isCollapsed ? 0 : 24),
                    bottomRight: Radius.circular(isCollapsed ? 0 : 24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade900.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: FlexibleSpaceBar(
                  centerTitle: true,
                  title: AnimatedOpacity(
                    duration: Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'YaarKhata',
                            style: TextStyle(
                              fontSize: isCollapsed ? 24 : 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.black38,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  titlePadding: EdgeInsets.only(
                    left: 16,
                    bottom: isCollapsed ? 16 : 20,
                    right: 16,
                  ),
                ),
              );
            },
          );
        },
      ),
      actions: [],
    );
  }
}