#version 450 compatibility
#include "/lib/Settings.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

/*
const int colortex0Format = RGBA16;
*/

/* DRAWBUFFERS:0 */

const float sunPathRotation = -50;

const bool colortex6Clear = false;

varying vec2 texcoord;

flat in mat2x3 lightVec;
flat in mat2x3 sunVec;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform float viewWidth, viewHeight, aspectRatio;
uniform int frameCounter;
uniform int isEyeInWater;
uniform vec3 skyColor;
uniform float near, far;





uniform ivec2 eyeBrightnessSmooth;

#define LOG2 log(2.0) 
#define rLOG2 1/LOG2
#define clamp01(x) clamp(x, 0, 1)

#include "/lib/Sky.fsh"

#define pow2(x) (x * x)
#define pow3(x) pow2(x) * x
#define pow4(x) pow2(pow2(x))
#define pow5(x) pow2(pow2(x)) * x

float depth0 = texture2D(depthtex0, texcoord.st).x;

float bayer2(vec2 a){
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a)   { return bayer2( 0.5  *a) * 0.25     + bayer2(a); }
float bayer8(vec2 a)   { return bayer4( 0.5  *a) * 0.25     + bayer2(a); }
float bayer16(vec2 a)  { return bayer4( 0.25 *a) * 0.0625   + bayer4(a); }
float bayer32(vec2 a)  { return bayer8( 0.25 *a) * 0.0625   + bayer4(a); }
float bayer64(vec2 a)  { return bayer8( 0.125*a) * 0.015625 + bayer8(a); }
float bayer128(vec2 a) { return bayer16(0.125*a) * 0.015625 + bayer8(a); }


vec2 haltonSequence(vec2 i, vec2 b) {
    vec2 f = vec2(1.0), r = vec2(0.0);
    while (i.x > 0.0 || i.y > 0.0) {
        f /= b;
        r += f * mod(i, b);
        i  = floor(i / b);
    }
    return r;
}

vec2 temporalJitter() {
    vec2 scale = 2.0 / vec2(viewWidth, viewHeight);
    return haltonSequence(vec2(frameCounter % 16), vec2(2.0, 3.0)) * scale + (-0.5 * scale);
}

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

vec3 calculateViewSpace(vec3 screenSpace) {
    screenSpace.xy += -temporalJitter() * 0.5;
    screenSpace = screenSpace * 2.0 - 1.0;
    return projMAD(gbufferProjectionInverse, screenSpace) / (screenSpace.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}


vec3 calculateScreenSpace(vec3 viewSpace) {
    return (diagonal3(gbufferProjection) * viewSpace + gbufferProjection[3].xyz) / -viewSpace.z * 0.5 + 0.5;
}

vec3 calculateShadowSpace(vec3 worldSpace) {
    vec3 shadowSpace = projMAD(shadowProjection, transMAD(shadowModelView, worldSpace + gbufferModelViewInverse[3].xyz));
    return shadowSpace * 0.5 + 0.5;
}

float distortionfactor(vec2 shadowspace){
float dist = length(abs(shadowspace * 1.165));
float distortion = ((1.0 - shadowBias) + dist * shadowBias) * 0.97;
return distortion;
}

float calculateShadow(sampler2D shadow, vec3 shadowSpace) {
    if (floor(shadowSpace.xy) != vec2(0.0) || shadowSpace.z > 1.0) return 1.0;
    return step(shadowSpace.z - 0.0002, texture2D(shadow, shadowSpace.xy).x);
}

float calculateShadowDepth(vec3 shadowspace) {
    return 0.0;


}

float dither5x3()
{
	const int ditherPattern[15] = int[15](
		 9, 3, 7,12, 0,
		11, 5, 1,14, 8,
		 2,13,10, 4, 6);

    vec2 position = floor(mod(vec2(texcoord.s * viewWidth,texcoord.t * viewHeight), vec2(5.0,3.0)));

	int dither = ditherPattern[int(position.x) + int(position.y) * 5];

	return float(dither) / 15.0f;
}

float ld(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

float dbao(sampler2D depth, float dither){
	float ao = 0.0;

	#ifndef DBAO
	return (1.0 * 1.0);
	#endif
	
	const int aoloop = DBAO_Loops;	//3 for lq, 6 for hq
	const int aoside = DBAO_Samples;	//4 for lq, 6 for hq
	float radius = 0.1 * DBAO_Radius;
	float dither2 = fract(dither5x3()-dither);
	float d = ld(texture2D(depth,texcoord.xy).r);
	const float piangle = 0.0174103175;
	float rot = 180/aoside*dither2;
	float size = radius*dither;
	float sd = 0.0;
	float angle = 0.0;
	float dist = 0.0;
	vec2 scale = vec2(1.0/aspectRatio,1.0) * gbufferProjection[1][1] / (2.74747742 * max(far*d,6.0));
	
	for (int i = 0; i < aoloop; i++) {
		for (int j = 0; j < aoside; j++) {
			sd = ld(texture2D(depth, texcoord.xy + vec2(cos(rot * piangle), sin(rot * piangle)) * size * scale).r);

			float aosample = far * (d - sd) / size;

			angle = clamp(0.5 - aosample, 0.0, 1.0);
			dist = clamp(0.0625  *aosample, 0.0, 1.0);
			sd = ld(texture2D(depth, texcoord.xy - vec2(cos(rot * piangle), sin(rot * piangle)) * size * scale).r);
			aosample = far*(d - sd) / size;
			angle += clamp(0.5 - aosample, 0.0, 1.0);
			dist += clamp(0.0625 * aosample, 0.0, 1.0);
			ao += clamp(angle + dist, 0.0, 1.0);
			rot += 180.0 / aoside;
		}
		rot += 180.0 / aoside;
		size += radius;						//lq
		//size = radius + radius*dither;	//hq
		//radius *= 2.0;					//hq
		angle = 0.0;
		dist = 0.0;
	}
	ao /= aoloop*aoside;
	
	return ao*sqrt(ao);
}

const vec3  sRGBApproxWavelengths = vec3( 610.0, 549.0, 468.0 );

float hash13(vec3 p3) {
    p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

#define max0(x) max(x, 0.0)
float radiation(in float temperature, in float wavelength)
{
    float e = exp(1.4387752e+7 / (temperature * wavelength));
    return 3.74177e+29 / (pow(wavelength, 5.0) * (e - 1.0));
}

vec3 radiation(in float t, in vec3 w)
{
    return vec3(
        radiation(t, w.x), 
        radiation(t, w.y), 
        radiation(t, w.z)
    );
}


void generateStars(inout vec3 color, in vec3 worldVector, in const float freq, in float visibility) {
    if (visibility >= 1.0) return;

	vec3 SSunColor = pow(GetSunColorZom(), vec3(2.0)) * vec3(1.0, 1.0, 1.0) * 7;
	vec3 SMoonColor = GetMoonColorZom() * vec3(0.8, 1.1, 1.3);
	vec3 SLightColor = SSunColor + SMoonColor;


    const float minTemp =  3500.0;
    const float maxTemp =  50500.0;
    const float tempRange = maxTemp - minTemp;
    const float frequency = freq;

    const float res = 0.5;

    vec3 p  = worldVector * res;
    vec3 id = floor(p);
    vec3 fp = fract(p) - 0.5;

    float rp    = hash13(id) * 6;
    float stars = pow(max0(0.75 - length(fp)) * 1.5, 11.0);

    float starTemp = (sin(rp / frequency * PI * 16.0) * 0.5 + 0.5) * tempRange + minTemp;
    vec3  starEmission = radiation(starTemp, sRGBApproxWavelengths) * 1.0e-15;

    color = vec3(stars) * step(rp, frequency) * pow2(1.0) * starEmission * 10 * ((SSunColor * 0.0) + (SMoonColor * 10.0));
}

void celshade(inout vec3 color) {

	float size = 0.63 * Cell_Outline_Thickness;
	vec2 pixel = 1.0 / vec2(viewWidth, viewHeight) * size;
    vec2 coord = texcoord;
	
	float outline;
	outline  = ld(texture2D(depthtex0, coord).r) * far * 8.0;
	outline -= ld(texture2D(depthtex0, coord + vec2( pixel.x * 2.0, 0.0)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2(-pixel.x * 2.0, 0.0)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2(0.0,  pixel.y * 2.0)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2(0.0, -pixel.y * 2.0)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2( pixel.x * 1.4,  pixel.y * 1.4)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2(-pixel.x * 1.4,  pixel.y * 1.4)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2( pixel.x * 1.4, -pixel.y * 1.4)).r) * far;
	outline -= ld(texture2D(depthtex0, coord + vec2(-pixel.x * 1.4, -pixel.y * 1.4)).r) * far;
	
	outline = clamp(1.0 - outline * 0.5 , 0.0 , 1.0);
//	outline = saturate(1.0 - outline * 0.5);
	
	color *= outline;
}

vec3 toSRGB(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, vec3(greaterThan(color, vec3(0.0031308))));
}

vec3 toLinear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), vec3(greaterThan(color, vec3(0.04045))));
}

vec3 AerialPerspective(float dist) {

   //if (moonFade <= 0.0) return vec3(0.0);

	vec3 colormult = vec3(1.0, 1.0, 1.0);

    float indoors       = 1.0 - clamp01((-eyeBrightnessSmooth.y + 230) / 100.0);

    float factor  = pow(dist, 1.0) * 0.0008 * Fog_Amount * (1.0 + isEyeInWater * 4);
	    if (isEyeInWater > 0.0) factor *= 15.0;
	    if (isEyeInWater > 0.0) colormult = vec3(0.3, 1.8, 1.6) * 0.01;
		if (isEyeInWater > 0.0) indoors = 1.0;



    return pow(vec3(0.2, 0.3, 1.25) * colormult, vec3(1.3 - clamp01(factor) * 0.4)) * factor * 2 * indoors;
}

vec4 VL() {
    vec4 endPos = gbufferProjectionInverse * (vec4(texcoord.st, texture2D(depthtex0, texcoord.st).r, 1.0) * 2.0 - 1.0);
    endPos /= endPos.w;
    endPos = shadowProjection * shadowModelView * gbufferModelViewInverse * endPos;
    vec4 startPos = shadowProjection * shadowModelView * gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0);
    vec4 dir = normalize(endPos - startPos);
    
    vec4 increment = dir * distance(endPos, startPos) / 5;
    startPos -= increment * bayer128(gl_FragCoord.xy);
    vec4 curPos = startPos;

    mat4 matrix = shadowModelViewInverse * shadowProjectionInverse;

    float lengthOfIncrement = length(increment);

    vec4 result = vec4(0.0);
    for (int j = 0; j < 5; j++) {
        curPos += increment;
        vec3 shadowPos = (curPos.xyz / vec3(vec2(distortionfactor(curPos.xy)), shadowZstretch)) * 0.5 + 0.5;
        float shadowTransparent = float(texture2D(shadowtex1, shadowPos.st).r > shadowPos.p - 0.00008);
        vec3 shadow = vec3(shadowTransparent);

        result += vec4(shadow * lengthOfIncrement, 1.0) * vec4(1.0);
    }

    return result / (1.0+result);
}

float hgPhase(float cosTheta, const float g) {
	const float gg = g * g;
	const float rGG = 0.2 / gg;
	const float p1 = (2.375 * (1.10 - gg)) * (1.0 / 3.14) * 0.2 * rGG;
	float p2 = (cosTheta * cosTheta + 1.0) * pow(-2.0 * g * cosTheta + 1.0 + gg, -1.5);
	return p1 * p2;
}

void main(){

vec3 color = toLinear(texture2D(colortex0, texcoord).rgb);
float depth0 = texture2D(depthtex0, texcoord).x;
vec3 normals = texture2D(colortex2, texcoord).rgb * 2.0 - 1.0;
vec3 specular = texture2D(colortex3, texcoord).rgb;

vec3 upvec = normalize(upPosition);
vec3 sunvec = normalize(sunPosition);
vec3 lightvec = normalize(shadowLightPosition);

vec3 SunColor = pow(GetSunColorZom(), vec3(2.0)) * vec3(1.0, 1.0, 1.0) * 7;
vec3 MoonColor = GetMoonColorZom() * vec3(0.8, 1.1, 1.3);
vec3 LightColor = SunColor + MoonColor;

vec3 ambientColor = vec3(0.8, 0.9, 1.2) * (SunColor + MoonColor) * 0.17;

vec3 lightmaps = texture2D(colortex1, texcoord).xyz;
lightmaps.xy = pow(lightmaps.xy, vec2(2.0));
float matIDs = lightmaps.z * 10;
float emitter = float(matIDs >= 2.5 &&  matIDs < 3.5);
vec3 screenspace = vec3(texcoord, depth0);

vec3 viewspace = calculateViewSpace(screenspace);

vec3 viewvec = normalize(viewspace);

vec3 worldspace = mat3(gbufferModelViewInverse) * viewspace;


vec3 shadowscreenspace = calculateShadowSpace(worldspace);

vec3 shadowspacedistorted;

shadowspacedistorted = shadowscreenspace * 2.0 - 1.0;
shadowspacedistorted = shadowspacedistorted / vec3(vec2(distortionfactor(shadowspacedistorted.xy)), shadowZstretch);
shadowspacedistorted = shadowspacedistorted * 0.5 + 0.5;


float shadow = calculateShadow(shadowtex0, shadowspacedistorted);

vec3 lighting = shadow * vec3(0.6) * max(0.0, dot(normals, normalize(shadowLightPosition))) * (SunColor + MoonColor);

float AO = dbao(depthtex0,bayer128(gl_FragCoord.xy));

lighting += pow2(lightmaps.y) * ambientColor * 0.5 * vec3(0.7, 0.9, 1.1) * AO;
lighting += (lightmaps.x + pow((length(color * 0.8)), 5.7) * 150 * emitter) * vec3(1.4, 0.4, 0.1) * 10.5;
lighting += specular.b * color * 50;

color *= lighting;

vec3 transmittance = vec3(1.0);

float visibility = 0.0;

//if (lightVec = -sunVec) visibility = 1.0;
vec3 colormult2 = vec3(1.0, 1.0, 1.0);
if (isEyeInWater > 0.0) colormult2 = vec3(0.3, 1.3, 1.6) * 3;
float multiplier = 1.0;
if (depth0 >= 1.0) {
     color = vec3(0.0);
	 generateStars(color, worldspace, 0.05, visibility);
     color += CalculateSunSpot(dot(viewvec, sunvec)) * SunColor * 150.0;
     color += CalculateSunSpot(dot(viewvec, -sunvec)) * MoonColor;
     color = sky_atmosphere(color, viewvec, upvec, sunvec, -sunvec, vec3(3.0), vec3(0.01), 8, transmittance, ambientColor) * 0.5;
     color += AerialPerspective(length(viewspace)) * ((SunColor * 0.1) + (MoonColor * 0.5)) * 0.5 * multiplier * (colormult2 * 2);
     #ifdef Volumetric_Light
     color += VL().x * hgPhase(dot(lightvec, viewvec), 0.5) * VL_Strength * ((SunColor * 0.33) + (MoonColor * 5)) * 0.2 * multiplier * colormult2 * 0.8;
     #endif
}

#ifdef Color_Compression
multiplier = 0.1;
#endif
#ifdef Cell_Shading
celshade(color);
#endif
#ifdef Normal_Debug
color = normals * 0.5 + 0.5;
#endif
#ifdef Fog
if (depth0 < 1.0) {
color += AerialPerspective(length(viewspace)) * ((SunColor * 0.8) + (MoonColor * 3)) * 0.5 * multiplier * (colormult2 * 2);
#ifdef Volumetric_Light
color += VL().x * hgPhase(dot(lightvec, viewvec), 0.5) * VL_Strength * ((SunColor * 1.2) + (MoonColor * 10)) * 0.2 * multiplier * colormult2 * 0.8;
#endif
}
#endif


gl_FragData[0] = vec4(toSRGB(color), 1.0);

}