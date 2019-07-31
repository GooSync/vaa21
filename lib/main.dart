import 'package:flutter/material.dart';
import 'package:page_transition_cube/view_pager/transformer_page_view.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'None',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key); // changed

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> images = [
    "assets/Hepburn2.jpg",
    "assets/Hepburn3.jpg",
    "assets/Hepburn4.jpg",
    "assets/Hepburn5.jpg",
  ];

  IndexController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = IndexController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ex 1')),
      body: Center(
        child: TransformerPageView.cube(
          index: _index,
          controller: _controller,
          onPageChanged: (int index) => setState(() => _index = index),
          itemCount: images.length,
          itemBuilder: (BuildContext context, int index) => Image.asset(images[index], fit: BoxFit.fill),
        ),
      ),
    );
  }
}
