

#define shadowBias 0.9
#define shadowZstretch 2.5
const int   noiseTextureResolution  = 64;
const float noiseResInverse         = 1.0 / noiseTextureResolution;

#define Parallax_Occlusion
#define Parallax_Depth 0.15 // [0.1 0.15 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0]
//#define Smooth_POM

#define Color_Downscale 10.0

//#define Tilt_Shift
//#define Distance_Blur

#define Focal_Length 35.0 
#define Depth_Of_Field
#define DepthOfFieldQuality 8 // [8 10 12 14 16 18 20 22 24 26 28 30]

#define FStop 5.6 // [1.4 2.0 4.0 5.6 8.1]

#define Fog_Amount 0.4 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0 10.0]

//#define Cell_Shading

//#define Normal_Debug

#define Bloom_Brightness 3.0

//#define Volumetric_Light
#define VL_Steps 4
#define VL_Distance 1000

#define Ambient_Occlusion

#define Cell_Outline_Thickness 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0]

#define AO_Quality 10

#define Fog

#define VL_Strength 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0 10.0]

#define Water_Brightness 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0 10.0]




#define PI    radians(180.0)
#define HPI   PI * 0.5
#define TAU   PI * 2.0
#define RCPPI 1.0 / PI
#define PHI   sqrt(5.0) * 0.5 + 0.5
#define GOLDEN_ANGLE TAU / PHI / PHI

#define Ambient_Occlusion