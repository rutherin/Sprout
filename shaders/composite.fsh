#version 450 compatibility
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"

const bool 		shadowHardwareFiltering = false;

varying vec2 texcoord;

varying vec3 lightVec;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;
varying vec3 downVec;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;

uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowcolor0;
uniform sampler2D shadowcolor1;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 shadowLightPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;
uniform int frameCounter;
uniform ivec2 eyeBrightness;

#include "lib/Sky.fsh"



vec4 aux1 = texture2D(colortex1, texcoord.st);

float depth0 = texture2D(depthtex0, texcoord.st).x;
float depth1 = texture2D(depthtex1, texcoord.st).x;

vec3 normals = texture2D(colortex2, texcoord).rgb * 2.0 - 1.0;
vec3 lightmaps = texture2D(colortex1, texcoord).xyz;

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
	#if defined TAA && !defined Color_Compression
    return haltonSequence(vec2(frameCounter % 16), vec2(2.0, 3.0)) * scale + (-0.5 * scale);
	#else
	return vec2(0.0);
	#endif
}

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

vec3 toShadowSpace(vec3 p3){
	vec4 p4 = vec4(p3, 1.0);

    p4 = gbufferModelViewInverse * p4;
    p4 = shadowModelView         * p4;
    p4 = shadowProjection        * p4;

    p4.xyz = p4.xyz * 0.5 + 0.5;

    return p4.xyz;
}

float distortionfactor(vec2 shadowSpace) {
float ShadowDistC = 0.97;

  if (eyeBrightness.y <= 200) {
  	ShadowDistC = 1.165;
  }

  vec2  coord = abs(shadowSpace);
  float dist = length(coord);
	return ((1.0 - shadowBias) + dist * shadowBias);
}

void biasShadow(inout vec3 shadowSpace) {
  shadowSpace    = shadowSpace * 2.0 - 1.0;
  shadowSpace.xy = shadowSpace.xy / distortionfactor(shadowSpace.xy);
  shadowSpace    = shadowSpace * vec3(0.5,0.5,0.2) + 0.5;
}

float shadowStep(sampler2D shadow, vec3 sPos) {
	return clamp01(1.0 - max(sPos.z - texture2D(shadow, sPos.xy).x, 0.0) * float(shadowMapResolution));
}

vec3 SunColor = pow(GetSunColorZom(), vec3(2.0)) * 4.3 * Sunlight_Brightness;
vec3 MoonColor = GetMoonColorZom() * vec3(0.3, 1.1, 2.3) * 0.8;
vec3 LightColor = SunColor + MoonColor;

#ifdef GI
  vec3 getGI(vec3 viewSpace) {
    //if (frameCounter % 2 == 0) return vec3(0.0);
    float weight = 0.0;
    vec3 light = vec3(0.0);
    
    const int ditherSize = 64;
    int index = bayer64x64(ivec2(texcoord*vec2(viewWidth,viewHeight)));
    float radius = 45.0;
    
    vec3 shadowSpaceNormal =mat3(gbufferModelViewInverse) * normals.xyz;
      shadowSpaceNormal     = mat3(shadowModelView) * shadowSpaceNormal;
    vec3 shadowSpace = toShadowSpace(viewSpace);
    
    vec3 shadowSpaceDistorted = shadowSpace;
    biasShadow(shadowSpaceDistorted);
    float shadow = shadowStep(shadowtex0, shadowSpaceDistorted);
    
    float multiplier = 1.0;
    #ifdef GI_SunlightCalc
    if (shadow > 0.5) multiplier *= 0.0;
    #endif

    int steps = (GI_QUALITY);
  
  #ifdef Variable_GI_Samples
    steps = int(GI_QUALITY * 0.5);
      if (lightmaps.y < 0.6) steps = int(GI_QUALITY * 0.66);
        else if (lightmaps.y < 0.6) steps = (GI_QUALITY);
  #endif
    
  	for (int i = 0; i < steps; i++) {
  		vec2 point = circlemap(
  			lattice(i * (ditherSize*ditherSize) + index , (ditherSize*ditherSize) * steps)
  		) * radius / float(shadowMapResolution);
  		
  		vec3 shadowCoord = shadowSpace + vec3(point, 0.0);
  		vec3 shadowCoordDistorted = shadowCoord;
  		biasShadow(shadowCoordDistorted);
  		
  		float shadowDepth = texture2D(shadowtex0, shadowCoordDistorted.xy).x;
  		      shadowDepth = ((shadowDepth * 2.0 - 1.0) * 2.5) * 0.5 + 0.5;
  		
  		vec3 sampleCoord = vec3(shadowCoord.xy, shadowDepth) - shadowSpace;
  		vec3 sampleCoordNormalized = normalize(sampleCoord);
  		
  		float falloff = pow(max0(1.0 - (flength(vec3(sampleCoord.xy, sampleCoord.z) * shadowMapResolution) / radius)), 1.0);
  		if (falloff < 0.1) continue;
  		
  		float diffuse = mDot(normalize(vec3(sampleCoord.xy, -sampleCoord.z)), shadowSpaceNormal.xyz);
  		if (diffuse < 0.1) continue;
  		
  		vec3 normalSample    = texture2D(shadowcolor1, shadowCoordDistorted.xy).rgb * 2.0 - 1.0;
  		     normalSample.xy = -normalSample.xy;
  		
  		float bounceDirection = mDot(sampleCoordNormalized, normalSample);
		if (bounceDirection <= 0.0) continue;
  		
  		light += toLinear(shadow2DLod(shadowcolor0, shadowCoordDistorted, 4.0).rgb) * (falloff * bounceDirection * diffuse);
  		weight++;
    }
	
    return light * 15.0 / steps * multiplier * (GI_Brightness) * 2 * (SunColor + (MoonColor * 0.0));
  }
#endif

/* DRAWBUFFERS:4 */

void main() {
	vec3 screenspace = vec3(texcoord, depth0);
	vec3 viewspace = calculateViewSpace(screenspace);	
	vec3 gi = vec3(1.0);
	
	#ifdef GI
		gi = getGI(viewspace);
	#endif

	gl_FragData[0] = vec4(toSRGB(gi), 1.0);
}
