
/*******************************************************************************
 - Sky Constants
 ******************************************************************************/

const float atmosphere_planetRadius = 6731e3; // Should probably move this to somewhere else.

const vec2  atmosphere_scaleHeights     = vec2(8.0e3, 1.2e3);
const float atmosphere_atmosphereHeight = 110e3;

const float atmosphere_mieg = 0.77;

const float airNumberDensity       = 2.6867774e19; // Couldn't find it for air, so just using value for an ideal gas. Not sure how different it is for actual air.
const float ozoneConcentrationPeak = 8e-6;
const float ozoneNumberDensity     = airNumberDensity * ozoneConcentrationPeak;
const vec3  ozoneCrossSection      = vec3(4.51103766177301E-21, 3.2854797958699E-21, 1.96774621921165E-22);

const vec3 atmosphere_coefficientRayleigh = vec3(4.593e-6, 1.097e-5, 2.716e-5);
const vec3 atmosphere_coefficientOzone    = ozoneCrossSection * ozoneNumberDensity;
const vec3 atmosphere_coefficientMie      = vec3(2.500e-6, 2.500e-6, 2.500e-6); // Should be >= 2e-6, depends heavily on conditions. Current value is just one that looks good.

// The rest of these constants are set based on the above constants
const vec2  atmosphere_inverseScaleHeights     = 1.0 / atmosphere_scaleHeights;
const vec2  atmosphere_scaledPlanetRadius      = atmosphere_planetRadius * atmosphere_inverseScaleHeights;
const float atmosphere_atmosphereRadius        = atmosphere_planetRadius + atmosphere_atmosphereHeight;
const float atmosphere_atmosphereRadiusSquared = atmosphere_atmosphereRadius * atmosphere_atmosphereRadius;

const mat2x3 atmosphere_coefficientsScattering  = mat2x3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie);
const mat3   atmosphere_coefficientsAttenuation = mat3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie * 1.11, atmosphere_coefficientOzone); // commonly called the extinction coefficient

#define phaseg0 0.25

/*******************************************************************************
 - Phases
 ******************************************************************************/

float sky_rayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / 3.14;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float sky_miePhase(float cosTheta, const float g) {
	const float gg = g * g;
	const float rGG = 1.0 / gg;
	const float p1 = (0.375 * (1.0 - gg)) / 3.14 * 0.5 * rGG;
	float p2 = (cosTheta * cosTheta + 1.0) * pow(-2.0 * g * cosTheta + 1.0 + gg, -1.5);
	return p1 * p2;
}

vec2 sky_phase(float cosTheta, const float g) {
	return vec2(sky_rayleighPhase(cosTheta), sky_miePhase(cosTheta, g));
}

/*******************************************************************************
 - Sky Functions
 ******************************************************************************/


float CalculateSunSpot(float VdotL) {
	const float sunAngularSize = 0.845;
    const float sunRadius = radians(sunAngularSize);
    const float cosSunRadius = cos(sunRadius);
    const float sunLuminance = 1.0 / ((1.0 - cosSunRadius) * PI);

	return step(cosSunRadius, VdotL) * sunLuminance;
}

//Temporary moon disk untill we added a moon texture
float CalculateMoonSpot(float VdotL) {
	const float moonAngularSize = 0.545;
    const float moonRadius = radians(moonAngularSize);
    const float cosMoonRadius = cos(moonRadius);
	const float moonLuminance = 1.0 / ((1.0 - cosMoonRadius) * PI);

	return step(cosMoonRadius, VdotL) * moonLuminance;
}

/*******************************************************************************
 - Sky Functions
 ******************************************************************************/

// No intersection if returned y component is < 0.0
vec2 rsi(vec3 position, vec3 direction, const float radius) {
	float PoD = dot(position, direction);
	const float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
	      delta = sqrt(delta);

	return -PoD + vec2(-delta, delta);
}

vec3 sky_atmosphereDensity(float centerDistance) {
	vec2 rayleighMie = exp(centerDistance * -atmosphere_inverseScaleHeights + atmosphere_scaledPlanetRadius);
	float ozone = exp(-max(0.0, (35000.0 - centerDistance) - atmosphere_planetRadius) /  5000.0)
	            * exp(-max(0.0, (centerDistance - 35000.0) - atmosphere_planetRadius) / 15000.0);
	return vec3(rayleighMie, ozone);
}

// I don't know if "thickness" is the right word, using it because Jodie uses it for that and I can't think of (or find) anything better.
vec3 sky_atmosphereThickness(vec3 position, vec3 direction, float rayLength, const float steps) {
	float stepSize  = rayLength / steps;
	vec3  increment = direction * stepSize;
	position += increment * 0.5;

	vec3 thickness = vec3(0.0);
	for (float i = 0.0; i < steps; ++i, position += increment) {
		thickness += sky_atmosphereDensity(length(position));
	}

	return thickness * stepSize;
}
vec3 sky_atmosphereThickness(vec3 position, vec3 direction, const float steps) {
	float rayLength = dot(position, direction);
	      rayLength = sqrt(rayLength * rayLength + atmosphere_atmosphereRadiusSquared - dot(position, position)) - rayLength;

	return sky_atmosphereThickness(position, direction, rayLength, steps);
}

vec3 sky_atmosphereOpticalDepth(vec3 position, vec3 direction, float rayLength, const float steps) {
	return atmosphere_coefficientsAttenuation * sky_atmosphereThickness(position, direction, rayLength, steps);
}
vec3 sky_atmosphereOpticalDepth(vec3 position, vec3 direction, const float steps) {
	return atmosphere_coefficientsAttenuation * sky_atmosphereThickness(position, direction, steps);
}

vec3 sky_atmosphereTransmittance(vec3 position, vec3 direction, const float steps) {
	return exp2(-sky_atmosphereOpticalDepth(position, direction, steps) * rLOG2);
}

vec3 GetSunColorZom() {
	return sky_atmosphereTransmittance(vec3(0.0, atmosphere_planetRadius, 0.0), normalize(mat3(gbufferModelViewInverse) * (sunPosition * 0.01)), 3) * vec3(1.0);
}

vec3 GetMoonColorZom() {
	return sky_atmosphereTransmittance(vec3(0.0, atmosphere_planetRadius, 0.0), normalize(mat3(gbufferModelViewInverse) * (-sunPosition * 0.01)), 2) * vec3(0.1);
}

vec3 sky_atmosphere(vec3 background, vec3 viewVector, vec3 upVector, vec3 sunVector, vec3 moonVector, vec3 sunIlluminance, vec3 moonIlluminance, const int iSteps, inout vec3 transmittance, vec3 ambientColor) {
	//const int iSteps = 25; // For very high quality: 50 is enough, could get away with less if mie scale height was lower
	const int jSteps = 5;  // For very high quality: 10 is good, can probably get away with less

	vec3 viewPosition = (atmosphere_planetRadius + cameraPosition.y) * upVector;

	vec2 aid = rsi(viewPosition, viewVector, atmosphere_atmosphereRadius);
	if (aid.y < 0.0) return background;
	vec2 pid = rsi(viewPosition, viewVector, atmosphere_planetRadius * 0.998);

	bool pi = pid.y >= 0.0;

	vec2 sd = vec2((pi && pid.x < 0.0) ? pid.y : max(aid.x, 0.0), (pi && pid.x > 0.0) ? pid.x : aid.y);

	float stepSize  = (sd.y - sd.x) / iSteps;
	vec3  increment = viewVector * stepSize;
	vec3  position  = viewVector * sd.x + (increment * 0.3 + viewPosition);

	vec2 phaseSun  = sky_phase(dot(viewVector, sunVector ), atmosphere_mieg);
	vec2 phaseMoon = sky_phase(dot(viewVector, moonVector), atmosphere_mieg);

	vec3 scatteringSun  = vec3(0.0);
	vec3 scatteringMoon = vec3(0.0);
	vec3 scatteringAmbient = vec3(0.0);
		 transmittance = vec3(1.0);

	for (int i = 0; i < iSteps; ++i, position += increment) {
		vec3 density          = sky_atmosphereDensity(length(position));
		if (density.y > 1e35) break;
		vec3 stepAirmass      = density * stepSize;
		vec3 stepOpticalDepth = atmosphere_coefficientsAttenuation * stepAirmass;

		vec3 stepTransmittance       = exp2(-stepOpticalDepth * rLOG2);
		vec3 stepTransmittedFraction = clamp((stepTransmittance - 1.0) / -stepOpticalDepth, 0.0, 1.0);
		vec3 stepScatteringVisible   = transmittance * stepTransmittedFraction;

		scatteringSun  += (atmosphere_coefficientsScattering * (stepAirmass.xy * phaseSun )) * stepScatteringVisible * sky_atmosphereTransmittance(position, sunVector,  jSteps);
		scatteringMoon += (atmosphere_coefficientsScattering * (stepAirmass.xy * phaseMoon)) * stepScatteringVisible * sky_atmosphereTransmittance(position, moonVector, jSteps) * 2;
		scatteringAmbient += (atmosphere_coefficientsScattering * (stepAirmass.xy * phaseg0)) * stepScatteringVisible;

		transmittance  *= stepTransmittance;
	}

	vec3 scattering = scatteringSun * sunIlluminance + scatteringMoon * moonIlluminance + scatteringAmbient / 3.14 * ambientColor * 0.1;

	return background * transmittance + scattering * (2 * PI) * vec3(0.5, 0.9, 1.0);
}
