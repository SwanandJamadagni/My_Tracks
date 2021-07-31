import 'dart:io';
// ignore: unused_import
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
// ignore: unused_import
import 'package:audioplayers/audioplayers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_file_manager/flutter_file_manager.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:path_provider_ex/path_provider_ex.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:id3/id3.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'dart:convert';
// ignore: unused_import
import 'package:flutter_launcher_icons/android.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyAudioPlayer(),
    );
  }
}

class MyAudioPlayer extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _MyAudioPlayer();
  }
}

class _MyAudioPlayer extends State<MyAudioPlayer> with TickerProviderStateMixin {
  var files;
  var fm;
  AudioPlayer audioPlayer = AudioPlayer();
  var meta = [];
  var metadisplay = [];
  var albums = [];
  var artists = [];
  var genres = [];
  var years = [];
  var filteredSongs = [];
  late AnimationController animationCntrl;
  late Animation<double> con1animation;
  late Animation<double> con2animation;
  late Animation<double> imageanimation;
  bool isanimationcomplete=false;
  Duration duration = new Duration();
  Duration position = new Duration();
  bool isPlaying=false;
  bool isStoped=true;
  // ignore: non_constant_identifier_names
  int song_index=0;
  String ?chosenAlbum;
  String ?chosenArtist;
  String ?chosenGenre;
  String ?chosenYear;
  late File jsonFile;
  //late Directory jsondir;
  String jsonFileName = 'categories.json';
  //bool jsonexist = false;
  late Map<String, dynamic> jsonContent;
  bool isFiltered=false;
  String countFile = 'countFile.json';
  String playerState='';


  void getFiles() async {
    //asyn function to get list of files

    var storagepermission = await Permission.storage.status;
    if (!storagepermission.isGranted) await Permission.storage.request();

    List<StorageInfo> storageInfo = await PathProviderEx.getStorageInfo();
    var root = storageInfo[0].rootDir; //storageInfo[1] for SD card, geting the root directory
    var songsdir = await Directory(root + '/' + 'My_Tracks').create();
    if (await songsdir.exists()) {
      fm = FileManager(root: songsdir); //
    } else {
      fm = FileManager(root: Directory(root));
    }
    //files = await fm.dirsTree(); for directory/folder tree list
    files = await fm.filesTree(
        extensions: ["mp3","MP3","Mp3","mP3"] //optional, to filter files, remove to list all,
        //remove this if your are grabbing folder list
        );

    
    var noOffiles = await files.length;
    var appdir = Directory(root+'/'+'Android/data/com.example.my_tracks');
    Map<String, dynamic> fcMap;
    File cf = new File(appdir.path+'/'+countFile);

    if(await cf.exists()){
      fcMap = json.decode(cf.readAsStringSync());
      if(fcMap['File_Count'] != noOffiles){
        getAllMetadata();
        cf.deleteSync();
        cf.createSync();
        fcMap.clear();
        fcMap = {'File_Count':noOffiles};
        cf.writeAsStringSync(json.encode(fcMap));
      }
    }
    else{
      cf.createSync();
      fcMap = {'File_Count':noOffiles};
      cf.writeAsStringSync(json.encode(fcMap));
    }

    setState(() {}); //update the UI
  }

  void getSongMetadata(f) {
    MP3Instance mp3instance = new MP3Instance(f);

    /// parseTags() returns
    // 'true' if successfully parsed
    // 'false' if was unable to recognize tag so can't be parsed

    var keyArr = [' Title',' Album', ' Artist', ' Genre', ' Year'];

    if (mp3instance.parseTagsSync()) {
      meta = mp3instance.getMetaTags().toString().split(',');
      metadisplay.clear();

      for (int i = 0; i < meta.length; i++) {
        var key = meta[i].toString().split(':')[0];
        if (keyArr.contains(key)) {
          metadisplay.add(meta[i]);
        }
      }
      metadisplay.sort();
    }
    setState(() {});
  }
  void getAllMetadata() async{
    var albumlist = [];
    var artistlist = [];
    var genrelist = [];
    var yearlist = [];
    var distalbums = [];
    var distartists = [];
    var distgenres = [];
    var distyears = [];

    for(int i = 0; i < await files.length; i++ ){

        MP3Instance mp3instance = new MP3Instance(files[i].path);

        if (mp3instance.parseTagsSync()) {
          albumlist.add(mp3instance.getMetaTags()['Album']);
          artistlist.add(mp3instance.getMetaTags()['Artist']);
          genrelist.add(mp3instance.getMetaTags()['Genre']);
          yearlist.add(mp3instance.getMetaTags()['Year']);
        }
    }
      albumlist.removeWhere((value) => value == null);
      artistlist.removeWhere((value) => value == null);
      genrelist.removeWhere((value) => value == null);
      yearlist.removeWhere((value) => value == null);

      distalbums = albumlist.toSet().toList();
      distartists = artistlist.toSet().toList();
      distgenres = genrelist.toSet().toList();
      distyears = yearlist.toSet().toList();

      List<StorageInfo> storageInfo = await PathProviderEx.getStorageInfo();
      var root = storageInfo[0].rootDir; //storageInfo[1] for SD card, geting the root directory

      var appdir = Directory(root+'/'+'Android/data/com.example.my_tracks');
      
      File categoriesFile = new File(appdir.path+'/'+jsonFileName);

      if(categoriesFile.existsSync()){
        categoriesFile.deleteSync();
      }
      categoriesFile.createSync();

      Map<String, dynamic> categories = {'Albums':distalbums,'Artists':distartists,'Genres':distgenres,'Years':distyears};
      categoriesFile.writeAsStringSync(json.encode(categories));

      getCategories();

      setState(() {});
  }

    void getCategories() async{
      
      List<StorageInfo> storageInfo = await PathProviderEx.getStorageInfo();
      var root = storageInfo[0].rootDir; //storageInfo[1] for SD card, geting the root directory
      var appdir = Directory(root+'/'+'Android/data/com.example.my_tracks');

      jsonFile = new File(appdir.path+'/'+jsonFileName);
      if(await jsonFile.exists()){
        jsonContent = json.decode(jsonFile.readAsStringSync());

        setState(() {
          jsonContent = json.decode(jsonFile.readAsStringSync());
          albums = jsonContent['Albums'];
          artists = jsonContent['Artists'];
          genres = jsonContent['Genres'];
          years = jsonContent['Years'];
        });
      }
  }

  void filterSongs(){
    
    filteredSongs.clear();

    if(chosenAlbum==null && chosenArtist==null && chosenGenre==null && chosenYear==null){
        setState(() {
          isFiltered = false;
        });
    }
    else{
      for(int i = 0; i < files.length; i++ ){
        MP3Instance mp3instance = new MP3Instance(files[i].path);
        
        if (mp3instance.parseTagsSync()) {
          
          if(chosenAlbum != null && mp3instance.getMetaTags()['Album'] == chosenAlbum && !filteredSongs.contains(files[i])){
            filteredSongs.add(files[i]);
          }
          
          if(chosenArtist != null && mp3instance.getMetaTags()['Artist'] == chosenArtist && !filteredSongs.contains(files[i])){
            filteredSongs.add(files[i]);
          }
          if(chosenGenre != null && mp3instance.getMetaTags()['Genre'] == chosenGenre && !filteredSongs.contains(files[i])){
            filteredSongs.add(files[i]);
          }
          if(chosenYear != null && mp3instance.getMetaTags()['Year'] == chosenYear && !filteredSongs.contains(files[i])){
            filteredSongs.add(files[i]);
          }
        }
      }
      setState(() {
        isFiltered = true;
      });
    }

  }

  @override
  void initState(){

    super.initState();

    getFiles(); //call getFiles() function on initial state.
    getCategories();
    
    animationCntrl = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    con1animation = Tween<double>(begin: 0.0, end: 250.0).animate(CurvedAnimation(parent: animationCntrl, curve: Curves.easeIn));
    con2animation = Tween<double>(begin: -250.0, end: 0.0).animate(CurvedAnimation(parent: animationCntrl, curve: Curves.easeIn));
    imageanimation = Tween<double>(begin: 0.0, end: 10.0).animate(CurvedAnimation(parent: animationCntrl, curve: Curves.easeIn));

    audioPlayer.onDurationChanged.listen((d) {setState(() {
      duration=d;
    }); });

    audioPlayer.onAudioPositionChanged.listen((p) {setState(() {
      position=p;
    });});

      audioPlayer.onPlayerCompletion.listen((event) {
    setState(() {
      audioPlayer.play(isFiltered==false?files[song_index+1].path:filteredSongs[song_index+1].path, isLocal: true);
    });
  });

    audioPlayer.onPlayerStateChanged.listen((s) => {
    setState(() {
     playerState =  s.toString();
    })
  });

  }

  Widget albumart(BuildContext context) {
    return Container(
        height: (MediaQuery.of(context).size.height)-con1animation.value,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/default_album_art.jpg'),
            fit: BoxFit.fill,
          ),
          shape: BoxShape.rectangle
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: imageanimation.value,sigmaY: imageanimation.value),
          child: Container(
            color: Colors.white.withOpacity(0.0),) ,
        )
        );
  }

  Widget metadatalist(BuildContext context) {
    return 
    Container(
        padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
        height: isStoped==true?20:150,
        width: MediaQuery.of(context).size.width,
        child: ListView.builder(
            //padding: const EdgeInsets.all(8),
            itemCount: metadisplay.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                height: 30,
                color: Colors.white.withOpacity(0.0),
                child: Center(child: Text(metadisplay[index])),
              );
            })
            );
  }

  Widget progressbar(BuildContext context){
    return Container(
    padding: EdgeInsets.fromLTRB(5, 10, 5, 10),
    height: 50,
    width: MediaQuery.of(context).size.width,
    child: ProgressBar(
        progress: position,
        total: duration,
        progressBarColor: Colors.deepPurple,
        baseBarColor: Colors.deepPurpleAccent.withOpacity(0.25),
        bufferedBarColor: Colors.deepPurpleAccent.withOpacity(0.5),
        thumbColor: Colors.deepPurpleAccent,
        barHeight: 5.0,
        thumbRadius: 10.0,
        onSeek: (duration) {
          audioPlayer.seek(duration);
        },
      )
    );
  }

  Widget controlbuttons(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
        height: 50,
        width: MediaQuery.of(context).size.width,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                 audioPlayer.play(isFiltered==false?files[song_index-1].path:filteredSongs[song_index-1].path, isLocal: true);
                 getSongMetadata(isFiltered==false?files[song_index-1].path:filteredSongs[song_index-1].path);
                 setState(() {
                    song_index = song_index-1;
                    isPlaying = true;
                    isStoped=false;
                  });
                },
                icon: Icon(Icons.skip_previous,size: 30.0),
                color: Colors.deepPurpleAccent,
                
              ),
              IconButton(
                icon: isPlaying==false?Icon(Icons.play_arrow,size: 30.0):Icon(Icons.pause,size: 30.0),
                onPressed: () {
                  print(playerState);
                  if(playerState != PlayerState.PLAYING.toString() && playerState != PlayerState.PAUSED.toString() && playerState != PlayerState.STOPPED.toString()){
                    audioPlayer.play(isFiltered==false?files[song_index].path:filteredSongs[song_index].path, isLocal: true);
                    getSongMetadata(isFiltered==false?files[song_index].path:filteredSongs[song_index].path);
                  }
                  if(isPlaying==false){
                    audioPlayer.resume();
                    setState(() {
                      isPlaying = true;
                      isStoped=false;

                    });
                  }
                  else if(isPlaying==true){
                    audioPlayer.pause();
                    setState(() {
                      isPlaying = false;
                      isStoped=false;
                    });
                  }
                },
                color: Colors.deepPurpleAccent,
              ),
              IconButton(
                onPressed: () {
                  audioPlayer.release();
                  setState(() {
                    isPlaying = false;
                    isStoped = true;
                  });
                },
                icon: Icon(Icons.stop,size: 30.0),
                color: Colors.deepPurpleAccent,
              ),
               IconButton(
                onPressed: () {
                  audioPlayer.play(isFiltered==false?files[song_index+1].path:filteredSongs[song_index+1].path, isLocal: true);
                  getSongMetadata(isFiltered==false?files[song_index+1].path:filteredSongs[song_index+1].path);
                  setState(() {
                    song_index = song_index+1;
                    isPlaying = true;
                    isStoped=false;
                  });
                },
                icon: Icon(Icons.skip_next,size: 30.0),
                color: Colors.deepPurpleAccent,
                
              )
            ]));
  }

  Widget songlist(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
        height: 250,
        width: MediaQuery.of(context).size.width,
        child: files == null
            ? Text("Searching Files")
            : ListView.builder(
                //if file/folder list is grabbed, then show here
                itemCount: isFiltered==false?files?.length ?? 0:filteredSongs.length,
                itemBuilder: (context, index) {
                  return 
                      Card(
                        child: ListTile(
                        title: Text(isFiltered==false?files[index].path.split('/').last:filteredSongs[index].path.split('/').last),
                        leading: Image.asset('images/default_album_art.jpg'),
                        trailing: Icon(Icons.play_arrow, color: Colors.deepPurpleAccent),
                        onTap: () {
                          audioPlayer.play(isFiltered==false?files[index].path:filteredSongs[index].path, isLocal: true);
                          getSongMetadata(isFiltered==false?files[index].path:filteredSongs[index].path);
                          setState(() {
                            isPlaying = true;
                            isStoped=false;
                            song_index = index;
                          });
                        },
                      )
                    );
                },
              )
              );
  }

  Widget con1(BuildContext context) {
    return 
    Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      alignment: Alignment.topCenter,
      child: Column(children: [
        albumart(context)
      ]),
    );
  }

    Widget con2(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25.0),topRight: Radius.circular(25.0)),
        color: Colors.white
      ),
      child: Column(
        children: [
        metadatalist(context),
        progressbar(context),
        controlbuttons(context),
        songlist(context)
      ]),
    );
  }

  Widget dropdown(BuildContext context){
    return Column(
      children: [
          Container(
           padding: EdgeInsets.all(25),
           child: DropdownButton<String>(
              value: chosenAlbum,
              style: TextStyle(color: Colors.deepPurpleAccent),
              items: albums.map((value) {
                return DropdownMenuItem<String>(
                value: value,
                child: Container( 
                  height: 50,
                  width: 150,
                child: Text(value),
                )
              );
              }).toList(),
              hint: Text(
              "Albums",
              style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            onChanged: (String? value) {
              setState(() {
                chosenAlbum = value!;
              });
            }
           )
          ),
          Container(
          padding: EdgeInsets.all(25),
           child: DropdownButton<String>(
              value: chosenArtist,
              style: TextStyle(color: Colors.deepPurpleAccent),
              items: artists.map((value) {
                return DropdownMenuItem<String>(
                value: value,
                child: Container( 
                  height: 50,
                  width: 150,
                child: Text(value),
                )
              );
              }).toList(),
              hint: Text(
              "Artists",
              style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            onChanged: (String? value) {
              setState(() {
                chosenArtist = value!;
              });
            }
           )
          ),
          Container(
           padding: EdgeInsets.all(25),
           child: DropdownButton<String>(
              value: chosenGenre,
              style: TextStyle(color: Colors.deepPurpleAccent),
              items: genres.map((value) {
                return DropdownMenuItem<String>(
                value: value,
                child: Container( 
                  height: 50,
                  width: 150,
                child: Text(value),
                )
              );
              }).toList(),
              hint: Text(
              "Genre",
              style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            onChanged: (String? value) {
              setState(() {
                chosenGenre = value!;
              });
            }
           )
          ),
          Container(
           padding: EdgeInsets.all(25),
           child: DropdownButton<String>(
              value: chosenYear,
              style: TextStyle(color: Colors.deepPurpleAccent),
              items: years.map((value) {
                return DropdownMenuItem<String>(
                value: value,
                child: Container( 
                  height: 50,
                  width: 150,
                child: Text(value),
                )
              );
              }).toList(),
              hint: Text(
              "Years",
              style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            onChanged: (String? value) {
              setState(() {
                chosenYear = value!;
              });
            }
           )
          )
      ]
    );
  }

  Widget navbar(BuildContext context){
    return Drawer(
      child: ListView(
        children: [
          Container(
            height: 200,
            width: 100,
            decoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                image: DecorationImage(
                    fit: BoxFit.fill,
                    image: AssetImage('images/default_album_art.jpg'))
            ),
          ),
          Padding(padding: EdgeInsets.all(10)),
          dropdown(context),
          Padding(padding: EdgeInsets.all(10)),
          ElevatedButton(
                    style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.pressed))
                          return Colors.grey;
                        return Colors.white; // Use the component's default.
                      },
                    ),
                  ),
                  onPressed:(){
                      filterSongs();
                      Navigator.of(context).pop();
                    },
                  //color: Colors.white,
                  child: Text("Apply Filter",style: TextStyle(color: Colors.deepPurpleAccent))
          ),
          Padding(padding: EdgeInsets.all(10)),
          ElevatedButton(
                    style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.pressed))
                          return Colors.grey;
                        return Colors.white; // Use the component's default.
                      },
                    ),
                  ),
                  onPressed:(){
                      setState(() {
                        chosenAlbum = null;
                        chosenArtist = null;
                        chosenGenre = null;
                        chosenYear = null;
                        dropdown(context);
                        filterSongs();
                        Navigator.of(context).pop();
                      });
                    },
                  //color: Colors.white,
                  child: Text("Reset Filter",style: TextStyle(color: Colors.deepPurpleAccent))
                ),
        ]
      )
      );
  }

  animationInit(){
    if(isanimationcomplete){
      animationCntrl.reverse();
    }
    else{
      animationCntrl.forward();
    }
    isanimationcomplete = !isanimationcomplete;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: navbar(context),
        appBar: AppBar(
            title: Text("My_Tracks"), backgroundColor: Colors.deepPurpleAccent),
        body: Container(
          child: AnimatedBuilder(
          animation: animationCntrl,
          builder: (BuildContext context, widget) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
              Positioned(
                top: 0,
                child:con1(context)
                ),
              Positioned(
                  bottom: con2animation.value,
                  child: GestureDetector(
                    onTap: () {
                      animationInit();
                    },
                    child: con2(context),
                  ))
            ]);
          },
        )));
  }
}
