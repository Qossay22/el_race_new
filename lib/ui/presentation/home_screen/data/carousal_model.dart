import 'package:el_race/utils/string_utils.dart';

class CarousalModel {
  final String image;
  final String desc;

  CarousalModel({required this.image, required this.desc});
}

List<CarousalModel> carousalList = [
  CarousalModel(image: '$imagePrefixPng/carousal1.png', desc: '''
  The company is proud to announce the successful completion of the modern horse stables project located in Falaj Hazza Police Station. This project reflects our commitment to fine craftsmanship and innovation in equestrian infrastructure.'''),
  CarousalModel(
      image: '$imagePrefixPng/carousal2.png',
      desc:
          '''Al Race, a leading construction and infrastructure development company, announces the completion of a new Civil Defense building project aimed at enhancing community safety and emergency preparedness.'''),
  CarousalModel(image: '$imagePrefixPng/carousal3.png', desc: '''
  A state-of-the-art healthcare facility designed to enhance patient care in our community has been completed. This project aims to provide advanced medical services and improve accessibility for all residents.'''),
  CarousalModel(
      image: '$imagePrefixPng/carousal4.png',
      desc:
          '''Al Race is proud to announce the successful completion of Umm Kulthum School, a state-of-the-art educational facility designed to inspire and support the next generation of learners. The project has officially opened its doors to students and staff, marking a significant milestone for the community. A huge thank you to everyone involved in the project – our skilled workers, our supportive partners and the community for your encouragement. This new building stands as a testament to our commitment to quality and excellence.'''),
  CarousalModel(image: '$imagePrefixPng/carousal5.png', desc: '''
  We are pleased to announce the completion of our latest construction project. After months of hard work and dedication, our team has successfully realized this vision by developing a fully integrated sports building for Al Ain Club.''')
];
