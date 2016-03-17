# kxmovie-extended
Original source: https://github.com/kolyvan/kxmovie

kxmovie extended, to get your own ui controls and get screenshots from your movie.

#Usage

- Drop all files to your project.
- Add frameworks: MediaPlayer, CoreAudio, AudioToolbox, Accelerate, QuartzCore, OpenGLES and libz.dylib .
- Add libs: libkxmovie.a, libavcodec.a, libavformat.a, libavutil.a, libswscale.a, libswresample.a

#examples

*implement Delegate functions*

- called when video updates it duration (good callback for updating your own UI/Slider)

        func videoDidUpdateWithDuration(duration: CGFloat, andPosition position: CGFloat)

- called when video is finished

        func videoDidFinish()
