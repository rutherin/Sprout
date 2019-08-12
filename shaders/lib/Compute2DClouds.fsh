const float noiseRes = float(noiseTextureResolution);
const float noiseScale = 256.0 / noiseRes;

#define CLOUDS_2D
#define CLOUD_HEIGHT_2D   512  // [384 512 640 768]
#define CLOUD_COVERAGE_2D 0.5  // [0.3 0.4 0.5 0.6 0.7]
#define CLOUD_SPEED_2D    1.00 // [0.25 0.50 1.00 2.00 4.00]

vec3 SunColor = pow(GetSunColorZom(), vec3(2.0)) * vec3(1.5, 1.2, 1.05) * 2.5;
vec3 MoonColor = GetMoonColorZom() * vec3(0.8, 1.1, 1.3);
vec3 ambientColor = vec3(0.8, 0.9, 1.2) * (SunColor + MoonColor);
vec3 lightColor = SunColor + MoonColor;


float cubesmooth(float x) { return (x * x) * (3.0 - 2.0 * x); }
vec2 cubesmooth(vec2 x) { return (x * x) * (3.0 - 2.0 * x); }

float GetNoise(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + cubesmooth(coord - whole);
	
	return texture2D(noisetex, coord * noiseResInverse + madd).x;
}

vec2 GetNoise2D(vec2 coord) {
	const vec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + cubesmooth(coord - whole);
	
	return texture2D(noisetex, coord * noiseResInverse + madd).xy;
}

float GetCoverage2D(float clouds, float coverage) {
	return cubesmooth(clamp01((coverage + clouds - 1.0) * 1.1 - 0.1));
}

float CloudFBM1(vec2 coord, out mat4x2 c, vec3 weights, float weight) {
	float time = CLOUD_SPEED_2D * frameTimeCounter * 0.01;
	
	c[0]    = coord * 0.007;
	c[0]   += GetNoise2D(c[0]) * 0.3 - 0.15;
	c[0].x  = c[0].x * 0.35 + time;
	
	float cloud = -GetNoise(c[0]);
	
	c[1]    = c[0] * 4.0 - cloud * vec2(0.5, 1.35);
	c[1].x += time;
	
	cloud += GetNoise(c[1]) * weights.x;
	
	c[2]  = c[1] * vec2(15.0, 1.65) + time * vec2(3.0, 0.55) - cloud * vec2(1.5, 0.75);
	
	cloud += GetNoise(c[2]) * weights.y;
	
	c[3]   = c[2] * 3.0 + time;
	
	cloud += GetNoise(c[3]) * weights.z;
	
	cloud  = weight - cloud;
	
	cloud += GetNoise(c[3] * 3.0 + time) * 0.022;
	cloud += GetNoise(c[3] * 9.0 + time * 3.0) * 0.014;
	
	return cloud * 0.65;
}

float CloudFBM2(vec2 coord, out mat4x2 c, vec3 weights, float weight) {
	float time = CLOUD_SPEED_2D * frameTimeCounter * 0.01;
	
	c[0]    = coord * 0.007;
	c[0]   += GetNoise2D(c[0]) * 0.3 - 0.15;
	c[0].x  = c[0].x * 0.25 + time;
	
	float cloud = -GetNoise(c[0]);
	
	c[1]    = c[0] * 1.0 - cloud * vec2(0.5, 1.35);
	c[1].x += time;
	
	cloud += GetNoise(c[1]) * weights.x;
	
	c[2]  = c[1] * vec2(9.0, 1.65) + time * vec2(3.0, 0.55) - cloud * vec2(1.5, 0.75);
	
	cloud += GetNoise(c[2]) * weights.y;
	
	c[3]   = c[2] * 3.0 + time;
	
	cloud += GetNoise(c[3]) * weights.z;
	
	cloud  = weight - cloud;
	
	cloud += GetNoise(c[3] * 3.0 + time) * 0.022;
	cloud += GetNoise(c[3] * 9.0 + time * 3.0) * 0.014;
	
	return cloud * 0.77;
}

void Compute2DClouds(inout vec3 color, inout float cloudAlpha, vec3 ray, float sunglow) {
#ifndef CLOUDS_2D
	return;
#endif
	

	const float cloudHeight = CLOUD_HEIGHT_2D;
	
	vec3 rayPos = cameraPosition;
	
	float visibility = 0.2;
	
	if (ray.y <= 0.0 != rayPos.y >= cloudHeight) return;
	
	
	const float coverage = CLOUD_COVERAGE_2D * 1.16;
	const vec3  weights  = vec3(0.5, 0.135, 0.075);
	const float weight   = weights.x + weights.y + weights.z;
	
	vec2 coord1 = ray.xz * ((cloudHeight - rayPos.y) / ray.y) + rayPos.xz;
	vec2 coord2 = ray.xz * ((cloudHeight + 500.0 - rayPos.y) / ray.y) + rayPos.xz;
	
	mat4x2 coords1;
	mat4x2 coords2;

	// Start of code for second cloud layer, done first so it mixes correctly
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////

	
	cloudAlpha = CloudFBM1(coord2, coords2, weights, weight);
	cloudAlpha = GetCoverage2D(cloudAlpha, coverage);
	cloudAlpha = pow(cloudAlpha, 1.2);

	
	vec2 lightOffset = vec2(0.0, 0.2);
	
	float sunlight;
	sunlight  = -GetNoise(coords2[0] + lightOffset)            ;
	sunlight +=  GetNoise(coords2[1] + lightOffset) * weights.x;
	sunlight +=  GetNoise(coords2[2] + lightOffset) * weights.y;
	sunlight +=  GetNoise(coords2[3] + lightOffset) * weights.z;
	sunlight  = GetCoverage2D(weight - sunlight, coverage);
	sunlight  = pow(1.3 - sunlight, 5.5);
	sunlight *= mix(pow(cloudAlpha, 1.6) * 2.5, 2.0, sunglow);
	sunlight *= mix(1.0, 1.0, sqrt(sunglow));
	
	vec3 direct  = lightColor;
	
	vec3 ambient = mix(ambientColor, direct, 0.15) * 0.05;
	
	vec3 cloud = mix(ambient, direct, sunlight) * 20.0;
	
	color = mix(color, cloud, cloudAlpha * visibility);

	// Start of code for first cloud layer
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////

	cloudAlpha = CloudFBM2(coord1, coords1, weights, weight);
	cloudAlpha = GetCoverage2D(cloudAlpha, coverage);
	cloudAlpha = pow(cloudAlpha, 1.2);


	sunlight  = 0.0;
	sunlight  = -GetNoise(coords1[0] + lightOffset)            ;
	sunlight +=  GetNoise(coords1[1] + lightOffset) * weights.x;
	sunlight +=  GetNoise(coords1[2] + lightOffset) * weights.y;
	sunlight +=  GetNoise(coords1[3] + lightOffset) * weights.z;
	sunlight  = GetCoverage2D(weight - sunlight, coverage);
	sunlight  = pow(1.3 - sunlight, 5.5);
	sunlight *= mix(pow(cloudAlpha, 1.6) * 2.5, 2.0, sunglow);
	sunlight *= mix(1.0, 1.0, sqrt(sunglow));
	
	     direct  = lightColor;
	     direct *= vec3(0.4, 0.5, 0.6) * 3.0 * (SunColor + MoonColor);
	
	ambient = mix(ambientColor, direct, 0.15) * 0.05;
	
	cloud = mix(ambient, direct, sunlight) * 20.0;
	
	color = mix(color, cloud, cloudAlpha * 0.1);
}