import 'package:el_race/utils/string_utils.dart';

class ShowIconModel {
  final String title;
  final String icon;

  const ShowIconModel({
    required this.title,
    required this.icon,
  });
}

List<ShowIconModel> favList = [
  ShowIconModel(title: 'Projects', icon: '$imagePrefixIcons/fav1.png'),
  ShowIconModel(title: 'Requests', icon: '$imagePrefixIcons/fav2.png'),
  ShowIconModel(title: 'HR', icon: '$imagePrefixIcons/fav3.png'),
  ShowIconModel(title: 'Add', icon: '$imagePrefixIcons/fav4.png'),
];

List<ShowIconModel> projectList = [
  ShowIconModel(title: 'HOSPITALS', icon: '$imagePrefixPng/project1.png'),
  ShowIconModel(title: 'SCHOOLS', icon: '$imagePrefixPng/project2.png'),
  ShowIconModel(title: 'CIVIL DEFENSE', icon: '$imagePrefixPng/project3.png'),
];
