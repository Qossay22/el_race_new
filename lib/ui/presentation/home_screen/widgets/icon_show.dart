import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';

class IconShow extends StatelessWidget {
  final IconData icon;
  final String title;
  final List listItems;
  final bool show;

  const IconShow({
    super.key,
    required this.icon,
    required this.title,
    required this.listItems,
    required this.show,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
            color: lightGrey,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(color: darkGrey, offset: Offset(2, 4), blurRadius: 12)
            ]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: blue,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                        color: blue, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 120,
                child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: show ? white : Colors.transparent,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          show ? darkGrey : Colors.transparent,
                                      offset: const Offset(2, 4),
                                      blurRadius: 12)
                                ]),
                            child: Image.asset(listItems[index].icon),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(listItems[index].title)
                        ],
                      );
                    },
                    separatorBuilder: (context, index) {
                      return const SizedBox(
                        width: 10,
                      );
                    },
                    itemCount: listItems.length),
              )
            ],
          ),
        ),
      ),
    );
  }
}
