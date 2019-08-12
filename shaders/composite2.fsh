#version 450 compatibility
#include "/lib/Settings.glsl"

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

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform vec3 cameraPosition, previousCameraPosition;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define lumaCoeff vec3(0.2125, 0.7254, 0.0721)

vec3 toSRGB(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, vec3(greaterThan(color, vec3(0.0031308))));
}

vec3 toLinear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), vec3(greaterThan(color, vec3(0.04045))));
}

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

vec2 calculateBlurTileOffset(const int id) {
	// offsets approximately follows a multiple of this: (1 - 4⁻ˣ) / 3

	const vec2 idMult = floor(id * 0.5 + vec2(0.0, 0.5));
	const vec2 offset = vec2(1.0, 2.0) * (1.0 - exp2(-2.0 * idMult)) / 3.0;

	const vec2 paddingPixels = vec2(2.0, 9.0); // Set as needed
	const vec2 paddingAccum  = idMult * paddingPixels;

	return offset + paddingAccum * pixel;
}

vec3 calculateBloomTile(vec2 coord, const float lod) {
	coord *= exp2(lod);

	if (clamp(coord, 0, 1) != coord) return vec3(0.0);

    vec2 resolution = pixel * exp2(lod);

    vec3  bloom       = vec3(0.0);
	float totalWeight = 0.0;
	
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float weight  = clamp(1.0 - length(vec2(x, y)) / 4.0, 0 , 1);
			      weight *= weight;
			
			bloom += toLinear(texture2DLod(colortex0, coord + vec2(x, y) * resolution, lod).rgb) * 1.2 * weight;
			totalWeight += weight;
		}
	}
	
	return bloom / totalWeight * 0.2;
}

vec3 calculateBloomTiles() {
    vec3 blurTiles = calculateBloomTile(texcoord - calculateBlurTileOffset(0), 1);
		for (int i = 1; i < 6; blurTiles += calculateBloomTile(texcoord - calculateBlurTileOffset(i), ++i));

    return toSRGB(blurTiles / 10.0);
}

float calculateAverageLuminance() {
    float avglod = int(exp2(min(viewWidth, viewHeight))) - 1;
	float averagePrevious = texture2DLod(colortex6, vec2(0.0) + pixel * 0.5, 0.0).a;
    float averageCurrent  = clamp(dot(texture2DLod(colortex0, vec2(0.5), avglod).rgb, lumaCoeff), 0.002, 0.25);
    float exposureDecay   = 0.08;

    float luminanceSmooth = mix(averagePrevious, averageCurrent, exposureDecay);

    return luminanceSmooth;
}


void main(){
vec3 color = texture2D(colortex0, texcoord).rgb;
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



vec3 antiAliased = mix(texture2D(colortex0, texcoord).rgb, clamp(texture2DLod(colortex6, prevCoord, 0.0).rgb, limits[0], limits[1]), sqrt(weight) * 0.5 + inversesqrt(weight * 2.0 + 4.0)); 

//colortex0write = vec4(calculateBloomTiles(), 1.0);
colortex6write = vec4(antiAliased, 1.0);

}
