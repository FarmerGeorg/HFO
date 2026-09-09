classdef ReportClaimsDotProductTest < matlab.unittest.TestCase
    % Verifies every hardcoded numeric claim in report.tex's Section 4
    % ("The Phasor Dot-Product Shortcut", \label{sec:pdh-dotproduct})
    % narrative prose. See the "Report Claim" entry in ../CONTEXT.md for
    % the full convention.

    properties (Constant)
        ModulationFrequencyHz = 15e6
        ModulationIndex = ExampleModulationParameters.ModulationIndex
    end

    properties
        Cavity
        Sidebands
        Setup
        A0
        A1
        AMinus1
    end

    methods (TestMethodSetup)
        function createFixtures(obj)
            obj.Cavity = ExampleCavities.CriticalHighFinesse;
            obj.Sidebands = generatePhaseModulationSidebands(obj.ModulationIndex);
            obj.Setup = PdhMeasurementSetup(obj.Cavity, obj.Sidebands, obj.ModulationFrequencyHz);
            obj.A0 = PhasorMath.sidebandAmplitude(obj.Sidebands, 0);
            obj.A1 = PhasorMath.sidebandAmplitude(obj.Sidebands, 1);
            obj.AMinus1 = PhasorMath.sidebandAmplitude(obj.Sidebands, -1);
        end
    end

    methods (Test)
        function rearrangementMatchesOriginalErrorSignal(obj)
            % report.tex \S4.1: "using Re(conj(u))=Re(u) on the
            % E_refl,1 term ... lets the shared factor E_refl,0 be pulled
            % out from under a single, common conjugate" -- Eq.
            % (pdh-dotproduct-rearrangement) must equal the original
            % Section 3 error signal at every detuning, not just on
            % average.
            detuning = [0.5e6, 3e6, 15e6, -7e6];
            theta = pi/2;
            fm = obj.ModulationFrequencyHz;

            for k = 1:numel(detuning)
                erefl0 = obj.A0 * obj.Cavity.reflectionCoefficient(detuning(k));
                erefl1 = obj.A1 * obj.Cavity.reflectionCoefficient(detuning(k) + fm);
                ereflm1 = obj.AMinus1 * obj.Cavity.reflectionCoefficient(detuning(k) - fm);

                rearranged = real(erefl0 * conj(erefl1*exp(-1i*theta) + ereflm1*exp(1i*theta)));
                original = computePdhErrorSignalDotProduct(obj.Setup, detuning(k));

                obj.verifyEqual(rearranged, original, "RelTol", 1e-9);
            end
        end

        function dotProductIdentityMatchesOriginalErrorSignal(obj)
            % report.tex \S4.1: "varepsilon = Re[E_refl,0 * conj(E_refl,sb)]
            % = E_refl,0 . E_refl,sb" -- the final dot-product identity,
            % via PhasorMath.dotProduct directly, must also equal the
            % original Section 3 error signal.
            detuning = [0.5e6, 3e6, 15e6, -7e6];
            theta = pi/2;
            fm = obj.ModulationFrequencyHz;

            for k = 1:numel(detuning)
                erefl0 = obj.A0 * obj.Cavity.reflectionCoefficient(detuning(k));
                erefl1 = obj.A1 * obj.Cavity.reflectionCoefficient(detuning(k) + fm);
                ereflm1 = obj.AMinus1 * obj.Cavity.reflectionCoefficient(detuning(k) - fm);
                ereflSb = PhasorMath.combineAtDemodulationPhase(erefl1, ereflm1, theta);

                dotValue = PhasorMath.dotProduct(erefl0, ereflSb);
                original = computePdhErrorSignalDotProduct(obj.Setup, detuning(k));

                obj.verifyEqual(dotValue, original, "RelTol", 1e-9);
            end
        end

        function resonanceCaseWalkthroughDispersiveCasesMatchDescribedPhysics(obj)
            % report.tex \S4.2 ("A detuning-by-detuning walkthrough"),
            % Figure fig:pdh-resonance-case-walkthrough: the four claimed
            % mechanisms -- exact zero at carrier resonance (critical
            % coupling), the vanishing upper term at side-mode resonance,
            % the numeric peak sitting at the carrier's own 45-degree
            % point, and the off-resonance/side-mode cases both being
            % small (near-perpendicular Z and W) rather than exactly zero.
            fm = obj.ModulationFrequencyHz;
            theta = pi/2;
            Z = @(df) obj.A0 * obj.Cavity.reflectionCoefficient(df);
            W = @(df) PhasorMath.combineAtDemodulationPhase( ...
                obj.A1*obj.Cavity.reflectionCoefficient(df+fm), ...
                obj.AMinus1*obj.Cavity.reflectionCoefficient(df-fm), theta);

            obj.verifyEqual(Z(0), 0, "AbsTol", 1e-12);
            obj.verifyEqual(obj.A1*obj.Cavity.reflectionCoefficient(-fm+fm), 0, "AbsTol", 1e-12);

            fineDetuning = linspace(-1.3*fm, 1.3*fm, 400001);
            errorSignal = real(Z(fineDetuning)).*real(W(fineDetuning)) + imag(Z(fineDetuning)).*imag(W(fineDetuning));
            [peakValue, peakIdx] = max(abs(errorSignal));
            peakDetuning = fineDetuning(peakIdx);
            zPeak = Z(peakDetuning);

            obj.verifyEqual(peakDetuning/obj.Cavity.LinewidthFWHM, -0.501, "AbsTol", 5e-3);
            obj.verifyEqual(abs(real(zPeak)), abs(imag(zPeak)), "RelTol", 5e-3);
            obj.verifyEqual(peakValue, 0.339, "AbsTol", 5e-3);

            offResonanceEps = PhasorMath.dotProduct(Z(fm/2), W(fm/2));
            obj.verifyEqual(offResonanceEps, 0.060, "AbsTol", 5e-3);
            obj.verifyLessThan(abs(offResonanceEps), 0.2*peakValue);

            sideModeEps = PhasorMath.dotProduct(Z(-fm), W(-fm));
            obj.verifyEqual(sideModeEps, -0.006, "AbsTol", 2e-3);
            obj.verifyLessThan(abs(sideModeEps), 0.2*peakValue);
        end

        function resonanceCaseWalkthroughAmplitudeOnlyCasesCoincide(obj)
            % report.tex \S4.2, Figure
            % fig:pdh-resonance-case-walkthrough-absorption: "cases 3 and 4
            % coincide exactly" once phase is discarded -- the
            % side-mode-resonance detuning and the numerically-found
            % maximum-signal detuning must agree to within the search
            % grid's own resolution, and theta_demod=pi/2 must remain
            % identically blind at every detuning, not just a single
            % illustrative point.
            fm = obj.ModulationFrequencyHz;
            amplitudeOnlyResponse = @(f) abs(obj.Cavity.reflectionCoefficient(f));
            Z = @(df) obj.A0 * amplitudeOnlyResponse(df);
            Wq = @(df) PhasorMath.combineAtDemodulationPhase( ...
                obj.A1*amplitudeOnlyResponse(df+fm), obj.AMinus1*amplitudeOnlyResponse(df-fm), 0);
            Wi = @(df) PhasorMath.combineAtDemodulationPhase( ...
                obj.A1*amplitudeOnlyResponse(df+fm), obj.AMinus1*amplitudeOnlyResponse(df-fm), pi/2);

            fineDetuning = linspace(-1.3*fm, 1.3*fm, 400001);
            epsQ = PhasorMath.dotProduct(Z(fineDetuning), Wq(fineDetuning));
            [peakValue, peakIdx] = max(abs(epsQ));
            peakDetuning = fineDetuning(peakIdx);

            obj.verifyEqual(peakDetuning, -fm, "AbsTol", 1e3); % within 1kHz of fm=15MHz, nine orders of magnitude below fm
            obj.verifyEqual(peakValue, 0.339, "AbsTol", 5e-3);
            obj.verifyEqual(PhasorMath.dotProduct(Z(-fm), Wq(-fm)), -0.339, "AbsTol", 5e-3);

            epsI = PhasorMath.dotProduct(Z(fineDetuning), Wi(fineDetuning));
            obj.verifyEqual(epsI, zeros(size(epsI)), "AbsTol", 1e-9);
        end

        function sidebandResultantRotatesRigidlyOnlyWhenOneTermVanishes(obj)
            % report.tex \S4.1 ("What the demodulation phase actually
            % controls..."): at the side-mode-resonance detuning the upper
            % term is exactly zero, so E_refl,sb(theta) = E_refl,-1 *
            % exp(i*theta) alone -- a rigid rotation, verified across a
            % full sweep, not merely asserted from the algebraic form.
            fm = obj.ModulationFrequencyHz;
            upperAtSideMode = obj.A1 * obj.Cavity.reflectionCoefficient(-fm + fm);
            obj.verifyEqual(upperAtSideMode, 0, "AbsTol", 1e-12);

            lowerAtSideMode = obj.AMinus1 * obj.Cavity.reflectionCoefficient(-fm - fm);
            theta = linspace(0, 2*pi, 3601);
            % PhasorMath.combineAtDemodulationPhase requires a scalar
            % demodulationPhase, so the sweep is built directly here.
            W = upperAtSideMode.*exp(-1i*theta) + lowerAtSideMode.*exp(1i*theta);

            expectedAngle = angle(lowerAtSideMode) + theta;
            actualAngle = angle(W);
            angleError = mod(actualAngle - expectedAngle + pi, 2*pi) - pi;
            obj.verifyEqual(angleError, zeros(size(angleError)), "AbsTol", 1e-9);
        end

        function errorSignalIsPureCosineGivingRealAndImaginaryPartsOfC(obj)
            % report.tex \S4.1 ("What the demodulation phase actually
            % controls..."): regardless of how the sideband resultant
            % itself moves, varepsilon(theta_demod) is a pure cosine in
            % theta_demod (amplitude |C|, phase arg(C)), so its values at
            % theta_demod=0 and pi/2 are exactly Re(C) and Im(C).
            fm = obj.ModulationFrequencyHz;
            detuning = [3e6, -7e6, 0.5e6, -fm+0.3e6];
            theta = linspace(0, 2*pi, 37);

            for k = 1:numel(detuning)
                df = detuning(k);
                erefl0 = obj.A0 * obj.Cavity.reflectionCoefficient(df);
                erefl1 = obj.A1 * obj.Cavity.reflectionCoefficient(df + fm);
                ereflm1 = obj.AMinus1 * obj.Cavity.reflectionCoefficient(df - fm);
                C = erefl1*conj(erefl0) + erefl0*conj(ereflm1);

                eps0 = computePdhErrorSignalDotProduct(obj.Setup, df, DemodulationPhase=0);
                epsI = computePdhErrorSignalDotProduct(obj.Setup, df, DemodulationPhase=pi/2);
                obj.verifyEqual(eps0, real(C), "AbsTol", 1e-10);
                obj.verifyEqual(epsI, imag(C), "AbsTol", 1e-10);

                % computePdhErrorSignalDotProduct/PhasorMath.combineAtDemodulationPhase
                % both require a scalar DemodulationPhase, so the theta
                % sweep is built directly here instead.
                resultantSweep = erefl1.*exp(-1i*theta) + ereflm1.*exp(1i*theta);
                epsSweep = real(erefl0)*real(resultantSweep) + imag(erefl0)*imag(resultantSweep);
                pureCosine = abs(C) * cos(angle(C) - theta);
                obj.verifyEqual(epsSweep, pureCosine, "AbsTol", 1e-10);
            end
        end

        function offResonancePerpendicularityIsIndependentOfDemodulationPhase(obj)
            % report.tex Sec 4.2 ("Case 1: off resonance"): the near-90-deg
            % angle between the carrier and the sideband resultant off
            % resonance is NOT created by theta_demod=pi/2 -- it holds at
            % every theta_demod, because E_refl,-1 ~= -E_refl,1 (odd-Bessel
            % sign flip acting on two nearly-equal reflectivities) makes
            % E_refl,sb(theta) = E_refl,1*(e^-ith - e^ith) = -2i*E_refl,1*
            % sin(theta) -- E_refl,1 rotated by exactly -90deg for every
            % theta, only its real scalar multiple changing with theta.
            fm = obj.ModulationFrequencyHz;
            df = fm/2; % this project's own "off resonance" case
            erefl0 = obj.A0 * obj.Cavity.reflectionCoefficient(df);
            erefl1 = obj.A1 * obj.Cavity.reflectionCoefficient(df + fm);
            ereflm1 = obj.AMinus1 * obj.Cavity.reflectionCoefficient(df - fm);

            % The idealized algebra (E_refl,-1 = -E_refl,1 exactly) must
            % rotate E_refl,1 by exactly -90 degrees for every theta. Range
            % excludes theta near 0 AND pi, where sin(theta)->0 and W->0
            % makes the angle numerically ill-conditioned on both ends.
            theta = linspace(deg2rad(20), deg2rad(160), 25);
            idealizedW = erefl1 * (exp(-1i*theta) - exp(1i*theta));
            angleFromErefl1 = mod(angle(idealizedW) - angle(erefl1) + pi, 2*pi) - pi;
            obj.verifyEqual(angleFromErefl1, -pi/2*ones(size(theta)), "AbsTol", 1e-9);

            % The real (non-idealized) angle between the carrier and the
            % actual sideband resultant must stay close to its pi/2 value
            % across the same theta sweep, not just AT pi/2 -- this is the
            % claim under test, not merely the idealized algebra above.
            actualW = erefl1*exp(-1i*theta) + ereflm1*exp(1i*theta);
            angleFromCarrier = mod(angle(actualW) - angle(erefl0) + pi, 2*pi) - pi;
            angleAtPiOver2 = mod(angle(erefl1*exp(-1i*pi/2) + ereflm1*exp(1i*pi/2)) - angle(erefl0) + pi, 2*pi) - pi;
            obj.verifyEqual(angleFromCarrier, angleAtPiOver2*ones(size(theta)), "AbsTol", deg2rad(1));
            obj.verifyEqual(rad2deg(angleAtPiOver2), -84.9, "AbsTol", 0.1);

            % No cavity at all (the idealized limit this case approaches):
            % the 90-degree angle is exact to floating-point precision, for
            % every theta_demod AND every modulation depth beta -- not a
            % tunable parameter of this system at all.
            for betaCheck = [0.3, 1.08, 2.0]
                sbCheck = generatePhaseModulationSidebands(betaCheck);
                a0c = PhasorMath.sidebandAmplitude(sbCheck, 0);
                a1c = PhasorMath.sidebandAmplitude(sbCheck, 1);
                am1c = PhasorMath.sidebandAmplitude(sbCheck, -1);
                wBare = a1c*exp(-1i*theta) + am1c*exp(1i*theta);
                angleBare = mod(angle(wBare) - angle(a0c) + pi, 2*pi) - pi;
                obj.verifyEqual(abs(angleBare), (pi/2)*ones(size(theta)), "AbsTol", 1e-9);
            end
        end
    end
end
