#version 450 compatibility
#include "/lib/settings.glsl"
#include "/lib/Utility.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

/* DRAWBUFFERS:60 */

layout (location = 0) out vec4 colortex6write;
layout (location = 1) out vec4 colortex0write;

const bool colortex0MipmapEnabled = true;
const bool colortex6MipmapEnabled = true;

varying vec2 texcoord;
uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform vec3 cameraPosition, previousCameraPosition;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

vec3 calculateViewSpace(vec3 screenSpace) {
    screenSpace = screenSpace * 2.0 - 1.0;
    return projMAD(gbufferProjectionInverse, screenSpace) / (screenSpace.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

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

vec2 computeCameraVelocity(in vec3 worldSpace) {
    vec3 projection = (cameraPosition - previousCameraPosition) + worldSpace;
         projection = mat3(gbufferPreviousModelView) * projection;
         projection = (diagonal3(gbufferPreviousProjection) * projection + gbufferPreviousProjection[3].xyz) / -projection.z * 0.5 + 0.5;

    return (texcoord - projection.xy);
}

vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);


vec3 SeishinBloomTile(const float lod, vec2 offset) {
	vec2 coord = (texcoord - offset) * exp2(lod);
	vec2 scale = pixelSize * exp2(lod);
	
	if (any(greaterThanEqual(abs(coord - 0.5), scale + 0.5)))
		return vec3(0.0);
	
	vec3  bloom       = vec3(0.0);
	float totalWeight = 0.0;
	
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float weight  = clamp01(1.0 - length(vec2(x, y)) / 4.0) * 1.1;
			      weight *= weight;
			
			bloom += toLinear(texture2DLod(colortex0, coord + vec2(x, y) * scale, lod).rgb) * weight;
			totalWeight += weight;
		}
	}
	
	return bloom / totalWeight;
}

vec3 SeishinBloom() {
	vec3 bloom = vec3(0.0);
	bloom += SeishinBloomTile(2.0, vec2(0.0                         ,                        0.0));
	bloom += SeishinBloomTile(3.0, vec2(0.0                         , 0.25   + pixelSize.y * 2.0));
	bloom += SeishinBloomTile(4.0, vec2(0.125    + pixelSize.x * 2.0, 0.25   + pixelSize.y * 2.0));
	bloom += SeishinBloomTile(5.0, vec2(0.1875   + pixelSize.x * 4.0, 0.25   + pixelSize.y * 2.0));
	bloom += SeishinBloomTile(6.0, vec2(0.125    + pixelSize.x * 2.0, 0.3125 + pixelSize.y * 4.0));
	bloom += SeishinBloomTile(7.0, vec2(0.140625 + pixelSize.x * 4.0, 0.3125 + pixelSize.y * 4.0));
	
	return bloom;
}

#define MotionBlurStrength 5.00 //[1.00 2.00 3.00 4.00 5.00 6.00 7.00 8.00 9.00 10.00]

vec3 motionBlur (vec3 color, float hand){
	if (hand < 0.5){
		float motionblur  = texture2D(depthtex1, texcoord.st).x;
		vec3 mblur = vec3(0.0);
		float mbwg = 0.0;
		float mbm = 0.0;
		vec2 pixel = 2.0 / vec2(viewWidth, viewHeight);
		
		vec4 currentPosition = vec4(texcoord.x * 2.0 - 1.0, texcoord.y * 2.0 - 1.0, 2.0 * motionblur - 1.0, 1.0);
		
		vec4 fragposition = gbufferProjectionInverse * currentPosition;
		fragposition = gbufferModelViewInverse * fragposition;
		fragposition /= fragposition.w;
		fragposition.xyz += cameraPosition;
		
		vec4 previousPosition = fragposition;
		previousPosition.xyz -= previousCameraPosition;
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition /= previousPosition.w;

		vec2 velocity = (currentPosition - previousPosition).xy;
		velocity = velocity / (1.0 + length(velocity)) * MotionBlurStrength * 0.02;
		
		vec2 coord = texcoord.st - velocity * (3.5 + bayer64(gl_FragCoord.xy));
		for (int i = 0; i < MOTION_BLUR_SAMPLES; ++i, coord += velocity){
			vec2 coordb = clamp(coord, pixel, 1.0-pixel);
			vec3 temp = texture2DLod(colortex0, coordb, 0).rgb;
			mblur += temp;
			mbwg += 1.0;
		}
		mblur /= mbwg;

		return mblur;
	}
	else return color;
}

void main(){
vec3 color = texture2D(colortex0, texcoord).rgb;
float hand = float(texture2D(depthtex1,texcoord.xy).r < 0.56);

float depth0 = texture2D(depthtex0, texcoord).x;

vec3 screenspace = vec3(texcoord, depth0);

vec3 viewspace = calculateViewSpace(screenspace);

vec3 worldspace = mat3(gbufferModelViewInverse) * viewspace;

vec2 CameraVelocity = computeCameraVelocity(worldspace);
vec2 prevCoord = -CameraVelocity + texcoord;

float weight = floor(prevCoord) == vec2(0.0) ? dot(0.5 - abs(fract(prevCoord / pixel) - 0.5), vec2(1.0)) : 0.0;

mat2x3 limits = mat2x3(0.0);

for (int i = -1; i <= 1; ++i) {
    for (int j = -1; j <= 1; ++j) {
        if (ivec2(i, j) == ivec2(0, 0)) continue;

        vec3 currentSample = texture2DLod(colortex0, ivec2(i, j) * pixel + texcoord, 0.0).rgb;

        if (ivec2(i, j) == ivec2(-1, -1)) {
            limits = mat2x3(currentSample, currentSample);

            continue;
        }

        limits[0] = min(currentSample, limits[0]);
        limits[1] = max(currentSample, limits[1]);
    }
}

#ifdef Motion_Blur
color = motionBlur(color,hand);
#endif

vec3 antiAliased = mix(color, clamp(texture2DLod(colortex6, prevCoord, 0.0).rgb, limits[0], limits[1]), sqrt(weight) * 0.5 + inversesqrt(weight * 2.0 + 4.0)); 
colortex0write = vec4(toSRGB(SeishinBloom()) * 0.1, 1.0);
colortex6write = vec4(antiAliased, 1.0);

}
