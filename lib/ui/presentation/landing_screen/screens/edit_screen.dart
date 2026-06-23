import 'package:el_race/ui/presentation/home_screen/widgets/card_tile.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../utils/orientation_helper.dart';

class AnimatedListView extends StatefulWidget {
  final String userName;
  const AnimatedListView({super.key, required this.userName});

  @override
  _AnimatedListViewState createState() => _AnimatedListViewState();
}

class _AnimatedListViewState extends State<AnimatedListView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 200), // Duration of the animation for each tile
    );
    _animationController.repeat(reverse: true); // Make the animation loop
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tilt animation for the container
    final tiltAnimation = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticInOut,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // HeaderWidget(username: widget.userName),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.floppy_disk,
                      color: shadowBlueDark,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Save',
                      style: TextStyle(color: shadowBlueDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Add the container with animation above the list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedBuilder(
                  animation: tiltAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                        angle: tiltAnimation.value, // Apply the tilt/rotation
                        child: Container(
                          height: 160,
                          width: 345,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(colors: [
                                buttonLight,
                                Colors.white,
                                buttonDark
                              ])),
                          child: Stack(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: SizeConfig().getWidth(40),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            bottomLeft: Radius.circular(20)),
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              buttonLight,
                                              buttonDark.withAlpha(
                                                  (0.2 * 255).toInt())
                                            ])),
                                    child: const SizedBox(
                                      height: 160,
                                    ),
                                  ),
                                  Container(
                                    width: SizeConfig().getWidth(40),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(20),
                                            bottomRight: Radius.circular(20)),
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            colors: [
                                              buttonLight,
                                              buttonDark.withAlpha(
                                                  (0.2 * 255).toInt())
                                            ])),
                                    child: const SizedBox(
                                      height: 160,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: SizeConfig().getHeight(20),
                                      horizontal: SizeConfig().getWidth(20)),
                                  child: Center(
                                    child: Icon(
                                      size: SizeConfig().getTextSize(90),
                                      CupertinoIcons.add_circled,
                                      color: shadowBlueDark,
                                    ),
                                  )),
                            ],
                          ),
                        ));
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: 20, // Number of items in the list
                  itemBuilder: (context, index) {
                    final tiltAnimation = Tween<double>(
                      begin: index.isOdd ? -0.01 : 0.01,
                      end: index.isOdd ? 0.01 : -0.01,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.elasticInOut,
                      ),
                    );
                    return AnimatedBuilder(
                      animation: tiltAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: tiltAnimation.value,
                          child: CardTile(itemIndex: index),
                        );
                      },
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(
                      height: 20,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
