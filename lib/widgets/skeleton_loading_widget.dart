  import 'package:flutter/material.dart';

  class SkeletonLoadingWidget extends StatefulWidget {
    final int itemCount;

    const SkeletonLoadingWidget({
      Key? key,
      this.itemCount = 5,
    }) : super(key: key);

    @override
    _SkeletonLoadingWidgetState createState() => _SkeletonLoadingWidgetState();
  }

  class _SkeletonLoadingWidgetState extends State<SkeletonLoadingWidget>
      with SingleTickerProviderStateMixin {
    late AnimationController _animationController;
    late Animation<double> _animation;

    @override
    void initState() {
      super.initState();
      _animationController = AnimationController(
        duration: Duration(milliseconds: 1500),
        vsync: this,
      )..repeat();

      _animation = Tween<double>(
        begin: -1.0,
        end: 2.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutSine,
      ));
    }

    @override
    void dispose() {
      _animationController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card Skeleton
            _buildSummaryCardSkeleton(),
            SizedBox(height: 16),
            // Friend List Skeletons
            ...List.generate(
              widget.itemCount,
                  (index) => _buildFriendItemSkeleton(),
            ),
          ],
        ),
      );
    }

    Widget _buildSummaryCardSkeleton() {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade200.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: 1,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon skeleton
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
              ),
              child: _buildShimmerEffect(),
            ),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title skeleton
                  Container(
                    height: 20,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _buildShimmerEffect(),
                  ),
                  SizedBox(height: 12),
                  // Subtitle skeleton
                  Container(
                    height: 16,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildShimmerEffect(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildFriendItemSkeleton() {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                ),
                child: _buildShimmerEffect(),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name skeleton
                    Container(
                      height: 18,
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: 150),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: _buildShimmerEffect(),
                    ),
                    SizedBox(height: 8),
                    // Balance skeleton
                    Container(
                      height: 14,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildShimmerEffect(),
                    ),
                  ],
                ),
              ),
              // Arrow skeleton
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                ),
                child: _buildShimmerEffect(),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildShimmerEffect() {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  _animation.value - 0.5,
                  _animation.value,
                  _animation.value + 0.5,
                ],
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade100,
                  Colors.grey.shade300,
                ],
              ),
            ),
          );
        },
      );
    }
  }

  // Alternative simpler version without animation
  class SimpleSkeletonLoadingWidget extends StatelessWidget {
    final int itemCount;

    const SimpleSkeletonLoadingWidget({
      Key? key,
      this.itemCount = 5,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card Skeleton
            _buildSummaryCardSkeleton(),
            SizedBox(height: 16),
            // Friend List Skeletons
            ...List.generate(
              itemCount,
                  (index) => _buildFriendItemSkeleton(),
            ),
          ],
        ),
      );
    }

    Widget _buildSummaryCardSkeleton() {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade200.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: 1,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
              ),
            ),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 16,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildFriendItemSkeleton() {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 18,
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: 150),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }