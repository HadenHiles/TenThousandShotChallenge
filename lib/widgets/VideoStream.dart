import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:video_player/video_player.dart';

class VideoStream extends StatefulWidget {
  const VideoStream({super.key, required this.url});

  final String url;

  @override
  State<VideoStream> createState() => _VideoStreamState();
}

class _VideoStreamState extends State<VideoStream> {
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoPlayerController!.initialize();
    super.initState();
  }

  @override
  void dispose() {
    _videoPlayerController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Chewie(
      controller: ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          bufferedColor: lighten(Theme.of(context).primaryColor, 0.2),
        ),
      ),
    );
  }
}
