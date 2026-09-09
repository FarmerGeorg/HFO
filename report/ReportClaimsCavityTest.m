classdef ReportClaimsCavityTest < matlab.unittest.TestCase
    % Verifies every hardcoded numeric claim in report.tex's Section 1
    % ("The Fabry-Perot Cavity", \label{sec:cavity}) narrative prose
    % against what OpticalCavity/ExampleCavities currently compute. See
    % the "Report Claim" entry in ../CONTEXT.md for the full convention
    % (forward citation format, the report.tex-side CHECKED-BY marker,
    % and why this test suite is split one class per report.tex section).

    methods (Test)
        function fsrIsExactlyOneGigahertz(obj)
            % report.tex \S1.2: "this evaluates to exactly FSR=1 GHz"
            cav = OpticalCavity(0.149896229, 1064e-9, 1, 1);
            obj.verifyEqual(cav.FSR, 1e9, "RelTol", 1e-9);
        end

        function reflectedPowerRisesToOneHalfAtHalfLinewidth(obj)
            % report.tex \S1.4 (paragraph after Figure 3): "|r|^2 rises to 0.5"
            cav = ExampleCavities.CriticalHighFinesse;
            r = cav.reflectionCoefficient(0.5*cav.LinewidthFWHM);
            obj.verifyEqual(abs(r)^2, 0.5, "AbsTol", 0.05);
        end

        function reflectedPowerIsZeroPointNineAtOnePointFiveLinewidths(obj)
            % report.tex \S1.4 (paragraph after Figure 3): "|r|^2=0.9"
            cav = ExampleCavities.CriticalHighFinesse;
            r = cav.reflectionCoefficient(1.5*cav.LinewidthFWHM);
            obj.verifyEqual(abs(r)^2, 0.9, "AbsTol", 0.05);
        end

        function reflectedPowerAtFixedDetuningGrowsWithFinesse(obj)
            % report.tex \S1.4: "reflected power goes from 0.0035 at
            % F=30 to 0.9997 at F~=31000"
            lowF = OpticalCavity(0.149896229, 1064e-9, 0.9, 0.9);
            highF = OpticalCavity(0.149896229, 1064e-9, 0.9999, 0.9999);
            obj.verifyEqual(abs(lowF.reflectionCoefficient(1e6))^2, 0.0035, "AbsTol", 5e-5);
            obj.verifyEqual(abs(highF.reflectionCoefficient(1e6))^2, 0.9997, "AbsTol", 5e-5);
        end

        function undercoupledResponseFigureMatchesCaptionedNumbers(obj)
            % report.tex Figure 5 caption: phase "-176.6 down to a minimum
            % near -208.8 and turning back toward -183.4", "net change
            % over the shown span is only -6.7", "min|r|^2=0.1219"
            cav = ExampleCavities.UndercoupledLowFinesse;
            zoomSpanHz = 5*cav.LinewidthFWHM;
            d = linspace(-zoomSpanHz, zoomSpanHz, 2001);
            r = cav.reflectionCoefficient(d);
            u = rad2deg(unwrap(angle(r)));

            obj.verifyEqual(u(1), -176.6, "AbsTol", 0.05);
            obj.verifyEqual(min(u), -208.8, "AbsTol", 0.05);
            obj.verifyEqual(u(end), -183.4, "AbsTol", 0.05);
            obj.verifyEqual(u(end)-u(1), -6.7, "AbsTol", 0.05);
            obj.verifyEqual(min(abs(r))^2, 0.1219, "AbsTol", 5e-5);
        end

        function overcoupledResponseFigureMatchesCaptionedNumbers(obj)
            % report.tex Figure 6 caption: phase "-173.0 to +173.0", "a
            % net change of +346.0", "the same min|r|^2=0.1219"
            cav = ExampleCavities.OvercoupledLowFinesse;
            zoomSpanHz = 5*cav.LinewidthFWHM;
            d = linspace(-zoomSpanHz, zoomSpanHz, 2001);
            r = cav.reflectionCoefficient(d);
            u = rad2deg(unwrap(angle(r)));

            obj.verifyEqual(u(1), -173.0, "AbsTol", 0.05);
            obj.verifyEqual(u(end), 173.0, "AbsTol", 0.05);
            obj.verifyEqual(u(end)-u(1), 346.0, "AbsTol", 0.05);
            obj.verifyEqual(min(abs(r))^2, 0.1219, "AbsTol", 5e-5);
        end
    end
end
