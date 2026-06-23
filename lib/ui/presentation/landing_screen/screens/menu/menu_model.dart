import 'package:el_race/utils/string_utils.dart';

class MenuModel {
  final String icon;
  final String title;

  MenuModel({required this.icon, required this.title});
}

List<MenuModel> menuListItems = [
  MenuModel(icon: '$imagePrefixIcons/fav1.png', title: 'PROJECTS'),
  MenuModel(icon: '$imagePrefixIcons/fav2.png', title: 'REQUESTS'),
  MenuModel(icon: '$imagePrefixIcons/fav3.png', title: 'HR'),
  MenuModel(icon: '$imagePrefixIcons/menu4.png', title: 'ACCOUNT'),
  MenuModel(icon: '$imagePrefixIcons/menu5.png', title: 'PURCHASE'),
  MenuModel(icon: '$imagePrefixIcons/menu6.png', title: 'PETTY CASH'),
  MenuModel(icon: '$imagePrefixIcons/menu7.png', title: 'TASKS'),
  MenuModel(icon: '$imagePrefixIcons/menu8.png', title: 'CLIENTS'),
  MenuModel(icon: '$imagePrefixIcons/menu9.png', title: 'SUBCONTRACT'),
  MenuModel(icon: '$imagePrefixIcons/menu10.png', title: 'LETTER'),
  MenuModel(icon: '$imagePrefixIcons/menu11.png', title: 'SUPPLIERS'),
  MenuModel(icon: '$imagePrefixIcons/menu12.png', title: 'COMPANY DOCUMENTS'),
  MenuModel(icon: '$imagePrefixIcons/menu13.png', title: 'EMPLOYEE'),
  MenuModel(icon: '$imagePrefixIcons/menu14.png', title: 'TO DO'),
  MenuModel(icon: '$imagePrefixIcons/menu15.png', title: 'COMPANY REQUESTS'),
  MenuModel(icon: '$imagePrefixIcons/menu16.png', title: 'ANNOUNCEMENT'),
  // MenuModel(icon: '$imagePrefixIcons/menu17.png', title: 'TIME SHEET'), // Hidden
];
