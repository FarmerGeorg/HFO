classdef ReportClaimsPdhTest < matlab.unittest.TestCase
    % Verifies every hardcoded numeric claim in report.tex's Section 3
    % ("The PDH Detection Chain", \label{sec:pdh-detection}) narrative
    % prose. See the "Report Claim" entry in ../CONTEXT.md for the full
    % convention.

    properties (Constant)
        ModulationFrequencyHz = 15e6
        ModulationIndex = ExampleModulationParameters.ModulationIndex
    end

    properties
        Cavity
        Sidebands
        Setup
    end

    methods (TestMethodSetup)
        function createFixtures(obj)
            obj.Cavity = ExampleCavities.CriticalHighFinesse;
            obj.Sidebands = generatePhaseModulationSidebands(obj.ModulationIndex);
            obj.Setup = PdhMeasurementSetup(obj.Cavity, obj.Sidebands, obj.ModulationFrequencyHz);
        end
    end

    methods (Test)
        function photodiodePowerHasExactlyFiveHarmonics(obj)
            % report.tex \S3.2: "Grouping Eq.(25)'s nine terms by
            % k=ell-ell' in {-2,-1,0,1,2}... The three k=0 terms... The
            % remaining six terms sit at k=+-1 (four terms...) and k=+-2
            % (one term each)"
            orders = obj.Sidebands.Order;
            [ellGrid, ellPrimeGrid] = ndgrid(orders, orders);
            k = ellGrid - ellPrimeGrid;

            obj.verifyEqual(numel(k), 9);
            obj.verifyEqual(sort(unique(k)), [-2; -1; 0; 1; 2]);
            obj.verifyEqual(nnz(k == 0), 3);
            obj.verifyEqual(nnz(k == 1), 2);
            obj.verifyEqual(nnz(k == -1), 2);
            obj.verifyEqual(nnz(k == 2), 1);
            obj.verifyEqual(nnz(k == -2), 1);
        end

        function betaNoteCoefficientMatchesDirectHarmonicExtraction(obj)
            % report.tex \S3.2: "the whole e^{i*omega_m*t} coefficient is
            % simply their sum, the beat-note coefficient" -- verified
            % against a direct numeric Fourier extraction of P(t)'s own
            % omega_m harmonic, not just algebra.
            detuning = 3.7e6;
            fm = obj.ModulationFrequencyHz;
            beta = obj.ModulationIndex;

            phi = @(ell) 2*pi*(detuning + ell*fm) / obj.Cavity.FSR;
            r = @(ell) obj.Cavity.reflectionCoefficient(detuning + ell*fm); %#ok<NASGU>
            J = @(ell) besselj(ell, beta);
            r0 = obj.Cavity.reflectionCoefficient(detuning);
            r1 = obj.Cavity.reflectionCoefficient(detuning + fm);
            rm1 = obj.Cavity.reflectionCoefficient(detuning - fm);
            C = J(0)*J(1)*(r1*conj(r0) - r0*conj(rm1)); %#ok<NASGU>

            samplesPerCycle = 64;
            t = (0:samplesPerCycle-1) / samplesPerCycle / fm;
            omega = 2*pi*fm;
            orders = obj.Sidebands.Order;
            reflectionAtLines = obj.Cavity.reflectionCoefficient(detuning + orders*fm);
            E = sum(obj.Sidebands.Amplitude .* reflectionAtLines .* exp(1i*orders*omega*t), 1);
            P = abs(E).^2;

            harmonics = fft(P) / samplesPerCycle;
            CFromFft = harmonics(2); % bin 2 = +1st harmonic (bin 1 is DC)

            obj.verifyEqual(C, CFromFft, "RelTol", 1e-9);
        end

        function errorSignalMatchesClosedForm(obj)
            % report.tex \S3.4: "varepsilon = Re[C*exp(-i*theta_demod)],
            % the PDH error signal -- exactly what
            % simulatePdhErrorSignal.m returns"
            detuning = [0.5e6, 3e6, 15e6, -7e6];
            demodulationPhase = pi/2;

            fm = obj.ModulationFrequencyHz;
            beta = obj.ModulationIndex;
            a0 = besselj(0, beta);
            a1 = besselj(1, beta);
            expected = zeros(size(detuning));
            for k = 1:numel(detuning)
                r0 = obj.Cavity.reflectionCoefficient(detuning(k));
                r1 = obj.Cavity.reflectionCoefficient(detuning(k) + fm);
                rm1 = obj.Cavity.reflectionCoefficient(detuning(k) - fm);
                C = a0*a1*(r1*conj(r0) - r0*conj(rm1));
                expected(k) = real(C * exp(-1i*demodulationPhase));
            end

            actual = simulatePdhErrorSignal(obj.Setup, detuning, DemodulationPhase=demodulationPhase);
            obj.verifyEqual(actual, expected, "RelTol", 5e-3);
        end

        function demodulationPhaseSuppressesCarrierFeatureByThirtyFold(obj)
            % report.tex \S3.4: "At Delta f_detune=0.5*Delta nu_FWHM...
            % varepsilon=0.339 at theta_demod=pi/2 but only
            % varepsilon=0.0113 at theta_demod=0 -- almost 30x smaller"
            detuning = 0.5 * obj.Cavity.LinewidthFWHM;
            errAtPiOver2 = simulatePdhErrorSignal(obj.Setup, detuning, DemodulationPhase=pi/2);
            errAtZero = simulatePdhErrorSignal(obj.Setup, detuning, DemodulationPhase=0);

            obj.verifyEqual(errAtPiOver2, 0.339, "AbsTol", 5e-4);
            obj.verifyEqual(errAtZero, 0.0113, "AbsTol", 5e-5);
            obj.verifyEqual(errAtPiOver2/errAtZero, 30, "RelTol", 0.02);
        end
    end
end
