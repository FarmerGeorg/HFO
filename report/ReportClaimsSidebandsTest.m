classdef ReportClaimsSidebandsTest < matlab.unittest.TestCase
    % Verifies every hardcoded numeric claim in report.tex's Section 2
    % ("Phase Modulation and Sidebands", \label{sec:sidebands}) narrative
    % prose. See the "Report Claim" entry in ../CONTEXT.md for the full
    % convention.

    methods (Test)
        function besselCoefficientsInJacobiAngerWorkedExample(obj)
            % report.tex \S2.2: "At beta=1.08, J_0(1.08)=0.7281,
            % J_1(1.08)=0.4656, ... J_2(1.08)~=0.1326"
            beta = ExampleModulationRegimes.Optimal;
            obj.verifyEqual(round(beta, 2), 1.08);
            obj.verifyEqual(besselj(0, beta), 0.7281, "AbsTol", 5e-5);
            obj.verifyEqual(besselj(1, beta), 0.4656, "AbsTol", 5e-5);
            obj.verifyEqual(besselj(2, beta), 0.1326, "AbsTol", 5e-5);
        end

        function optimalModulationDepthMaximizesCarrierSidebandProduct(obj)
            % report.tex \S2.3: "beta~=1.08 rad ... maximizing
            % J_0(beta)J_1(beta) at ~=0.339, more than double the
            % under-modulated regime's 0.145" and "J_1(beta) alone ... not
            % peaking until beta~=1.8"
            beta = ExampleModulationRegimes.Optimal;
            product = @(b) besselj(0, b) .* besselj(1, b);
            obj.verifyEqual(round(beta, 2), 1.08);
            obj.verifyEqual(product(beta), 0.339, "AbsTol", 5e-4);
            obj.verifyEqual(product(ExampleModulationRegimes.UnderModulated), 0.145, "AbsTol", 5e-4);

            j1PeakLocation = fminbnd(@(b) -besselj(1, b), 1, 3);
            obj.verifyEqual(round(j1PeakLocation, 1), 1.8);
        end

        function phasorResultantMagnitudeExcursionsAtOptimalModulationDepth(obj)
            % report.tex \S2.4: "dipping inside to |J_0(beta)|~=0.73 at
            % t=0 ... and bulging outside to ~=1.18 at the wobble's peak"
            beta = ExampleModulationRegimes.Optimal;
            J0 = besselj(0, beta);
            J1 = besselj(1, beta);
            obj.verifyEqual(round(J0, 2), 0.73);
            obj.verifyEqual(round(sqrt(J0^2 + 4*J1^2), 2), 1.18);
        end

        function secondOrderToFirstOrderRatioAcrossRegimes(obj)
            % report.tex \S2.3: "J_2(beta)/J_1(beta) ... 7.5% at the
            % under-modulated beta=0.3, 28.5% at the optimal beta~=1.08,
            % and 48.8% at the over-modulated beta=1.7"
            ratio = @(b) besselj(2, b) ./ besselj(1, b);
            obj.verifyEqual(round(100*ratio(ExampleModulationRegimes.UnderModulated), 1), 7.5);
            obj.verifyEqual(round(100*ratio(ExampleModulationRegimes.Optimal), 1), 28.5);
            obj.verifyEqual(round(100*ratio(ExampleModulationRegimes.OverModulated), 1), 48.8);
        end

        function carrierNullIsFirstZeroOfJ0(obj)
            % report.tex \S2.3: "beta=2.4048 ... the first zero of J_0"
            beta = ExampleModulationRegimes.CarrierNull;
            obj.verifyEqual(round(beta, 4), 2.4048);
            obj.verifyEqual(besselj(0, beta), 0, "AbsTol", 1e-8);
        end

        function iqModulatorDriveReproducesTheOptimalWorkedExampleNumbers(obj)
            % report.tex \S2.5: "s_I(t)=J_0(beta)=0.7281 (a pure DC bias)
            % and s_Q(t)=2*J_1(beta)*sin(omega_m t) swings between
            % +-0.9312"
            beta = ExampleModulationRegimes.Optimal;
            fm = ExampleModulationParameters.ModulationFrequencyHz;
            t = linspace(0, 2/fm, 5000);
            [inPhase, quadrature] = generateIqModulatorDrive(beta, fm, t);
            obj.verifyEqual(inPhase, 0.7281*ones(size(t)), "AbsTol", 5e-5);
            obj.verifyEqual(max(quadrature), 0.9312, "AbsTol", 5e-4);
            obj.verifyEqual(min(quadrature), -0.9312, "AbsTol", 5e-4);
        end

        function iqModulatorSpectrumHasNoEnergyBeyondFirstOrder(obj)
            % report.tex \S2.5: "has all of its energy at ell=0,+-1 and
            % none anywhere else, to within floating-point round-off"
            beta = ExampleModulationRegimes.Optimal;
            fm = ExampleModulationParameters.ModulationFrequencyHz;
            samplesPerCycle = 64;
            t = (0:samplesPerCycle-1) / samplesPerCycle / fm;
            [inPhase, quadrature] = generateIqModulatorDrive(beta, fm, t);
            harmonics = fft(inPhase + 1i*quadrature) / samplesPerCycle;
            populatedBins = mod([-1 0 1], samplesPerCycle) + 1;
            higherOrderBins = setdiff(1:samplesPerCycle, populatedBins);
            obj.verifyLessThan(max(abs(harmonics(higherOrderBins))), 1e-9);
        end
    end
end
