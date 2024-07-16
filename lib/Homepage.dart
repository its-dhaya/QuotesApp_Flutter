import 'dart:convert';
import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:http/http.dart' as http;
import 'package:share/share.dart';
import 'package:path/path.dart' as path;

class Homepage extends StatefulWidget {
  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Homepage> {
  late String quote, owner, imglink;
  bool working = false;
  final grey = Colors.blueGrey[800];
  late ScreenshotController screenshotController;

  @override
  void initState() {
    super.initState();
    screenshotController = ScreenshotController();
    quote = "";
    owner = "";
    imglink = "";
    getQuote();
  }

  // get a random Quote from the API
  getQuote() async {
    try {
      setState(() {
        working = true;
        quote = imglink = owner = "";
      });
      var response = await http.post(
          Uri.parse('http://api.forismatic.com/api/1.0/'),
          body: {"method": "getQuote", "format": "json", "lang": "en"});
      setState(() {
        try {
          var res = jsonDecode(response.body);
          owner = res["quoteAuthor"].toString().trim();
          quote = res["quoteText"].replaceAll("â", " ");
          getImg(owner);
        } catch (e) {
          getQuote();
        }
      });
    } catch (e) {
      offline();
    }
  }

  // if it is offline, show a fixed Quote
  offline() {
    setState(() {
      owner = "Janet Fitch";
      quote = "The phoenix must burn to emerge";
      imglink = "";
      working = false;
    });
  }

  // When copy button clicked, copy the quote to clipboard
copyQuote() {
  FlutterClipboard.copy('$quote\n- $owner').then((_) {
    Fluttertoast.showToast(
      msg: "Quote Copied",
      gravity: ToastGravity.BOTTOM,
    );
  }).catchError((error) {
    Fluttertoast.showToast(
      msg: "Failed to copy",
      gravity: ToastGravity.BOTTOM,
    );
  });
}

  // When share button clicked, share a text and screenshot of the quote
shareQuote() async {
  try {
    // Ensure the screenshots directory exists
    final directory = await getApplicationDocumentsDirectory();
    final screenshotDir = path.join(directory.path, 'screenshots');
    final screenshotDirectory = Directory(screenshotDir);

    if (!await screenshotDirectory.exists()) {
      await screenshotDirectory.create(recursive: true);
    }

    // Construct the path for the screenshot
    String filePath = path.join(screenshotDir, '${DateTime.now().toIso8601String()}.png');

    // Capture the screenshot
    final image = await screenshotController.capture();
    if (image != null) {
      // Save the image to the file
      final file = File(filePath);
      await file.writeAsBytes(image);

      // Share the screenshot
      Share.shareFiles([filePath], text: quote);
    }
  } catch (e) {
    print("Error capturing or sharing screenshot: $e");
  }
}


  // get image of the quote author, using Wikipedia Api
  getImg(String name) async {
    var image = await http.get(Uri.parse(
        "https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrlimit=1&prop=pageimages%7Cextracts&pithumbsize=400&gsrsearch=" +
            name +
            "&format=json"));

    setState(() {
      try {
        var res = json.decode(image.body)["query"]["pages"];
        res = res[res.keys.first];
        imglink = res["thumbnail"]["source"];
      } catch (e) {
        imglink = "";
      }
      working = false;
    });
  }

  // Choose to show the loaded image from the Api or the offline one
  Widget drawImg() {
    if (imglink.isEmpty) {
      return Image.asset("img/offline.jpg", fit: BoxFit.cover);
    } else {
      return Image.network(imglink, fit: BoxFit.cover);
    }
  }

  // Main build function
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grey,
      body: Screenshot(
        controller: screenshotController,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: <Widget>[
            drawImg(),
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.6, 1],
                  colors: [
                    grey!.withAlpha(70),
                    grey!.withAlpha(220),
                    grey!.withAlpha(255),
                  ],
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: quote.isNotEmpty ? '“ ' : "",
                      style: TextStyle(
                        fontFamily: "Ic",
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                      ),
                      children: [
                        TextSpan(
                          text: quote.isNotEmpty ? quote : "",
                          style: TextStyle(
                            fontFamily: "Ic",
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                          ),
                        ),
                        TextSpan(
                          text: quote.isNotEmpty ? '”' : "",
                          style: TextStyle(
                            fontFamily: "Ic",
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                            fontSize: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    owner.isEmpty ? "" : "\n" + owner,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Ic",
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: AppBar(
                title: Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Text(
                    "Motivational Quotes",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w400, fontSize: 25,color: Colors.white),
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          InkWell(
            onTap: !working ? getQuote : null,
            child: Icon(Icons.refresh, size: 35, color: Colors.white),
          ),
          InkWell(
            onTap: quote.isNotEmpty ? copyQuote : null,
            child: Icon(Icons.content_copy, size: 30, color: Colors.white),
          ),
          InkWell(
            onTap: quote.isNotEmpty ? shareQuote : null,
            child: Icon(Icons.share, size: 30, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
