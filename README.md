kxmovie-extended
==========================================================
Original source: https://github.com/kolyvan/kxmovie


FFmpegPlayer-iOS - A movie player for iOS based on FFmpeg.

kxmovie extended, to get your own ui controls and get screenshots from your movie.

### Build Instructions

First you need to download, configure and build [FFmpeg](http://ffmpeg.org/index.html). For this, open console and type in:
	
	cd kxmovie
	git submodule update --init	
	rake
	
#Usage

- Drop all files to your project.
- Add frameworks: MediaPlayer, CoreAudio, AudioToolbox, Accelerate, QuartzCore, OpenGLES and libz.dylib .
- Add libs: libkxmovie.a, libavcodec.a, libavformat.a, libavutil.a, libswscale.a, libswresample.a

#examples

1. *implement Delegate functions*

- implement **KxMovieViewDelegate** in your interface

- called when video updates it duration (good callback for updating your own UI/Slider)

        func videoDidUpdateWithDuration(duration: CGFloat, andPosition position: CGFloat)

- called when video is finished

        func videoDidFinish()

2. If you want to set the current position

        let value = CGFloat(Float(self.slider.value)*Float(self.kxMoviePlayer.decoder.duration))
        self.kxMoviePlayer.setMoviePosition(value)
        
3. Get a snapshot (UIImage) of current position

        self.kxMoviePlayer.glView.snapshot()
