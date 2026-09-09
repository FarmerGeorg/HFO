function generateReportFigures()
    % Regenerate every figure and table used by source/PDH/report/report.tex
    % from the actual OpticalCavity/sideband code, so the report can never
    % silently drift from the model. Run after any change to OpticalCavity,
    % generatePhaseModulationSidebands, or plotCavityResponse.
    picDir = fullfile(fileparts(mfilename("fullpath")), "pic");
    tableDir = fullfile(fileparts(mfilename("fullpath")), "tables");

    cavity = ExampleCavities.CriticalHighFinesse;

    exportCavityResponseFigure(cavity, picDir);
    exportGeometricSeriesConvergenceFigure(picDir);
    exportSidebandRegimesFigure(picDir);
    exportPhasorSnapshotFigure(picDir);
    exportIqModulatorSchematicFigure(picDir);
    exportIqModulatorSpectrumFigure(picDir);
    exportPhasorChainConceptualFigure(cavity, picDir);
    exportPdhDetectionChainSchematicFigure(picDir);
    exportPhotodiodePowerScanFigure(picDir);
    exportPdhDemodulatedSignalsFigure(picDir);
    exportCouplingRegimesFigure(picDir);
    exportCouplingRegimeResponsePlots(picDir);
    exportPdhResonanceCaseWalkthroughFigure(picDir);
    exportPdhResonanceCaseWalkthroughAbsorptionFigure(picDir);
    exportFinesseTable(tableDir);
    exportCouplingRegimesTable(tableDir);
end

function exportCavityResponseFigure(cavity, picDir)
    plotCavityResponse(cavity);
    exportReportFigure(picDir, "cavity-response.pdf");
end

function exportGeometricSeriesConvergenceFigure(picDir)
    % Partial sums of the round-trip geometric series vs. the exact closed
    % form, on resonance, for two finesse values -- shows that a
    % higher-finesse (narrower-linewidth) cavity needs more round trips to
    % converge, the same "long-lived resonance <-> narrow linewidth"
    % tradeoff discussed in the text.
    lowFinesseCavity = ExampleCavities.CriticalLowFinesse;
    highFinesseCavity = ExampleCavities.CriticalHighFinesse;

    roundTripCounts = round(logspace(0, 4, 60));
    lowFinesseError = partialSumError(lowFinesseCavity, 0, roundTripCounts);
    highFinesseError = partialSumError(highFinesseCavity, 0, roundTripCounts);

    figure("Name", "Geometric series convergence");
    loglog(roundTripCounts, lowFinesseError, "-o", "DisplayName", ...
        sprintf("Finesse = %.0f", lowFinesseCavity.Finesse));
    hold on;
    loglog(roundTripCounts, highFinesseError, "-o", "DisplayName", ...
        sprintf("Finesse = %.0f", highFinesseCavity.Finesse));
    hold off;
    grid on;
    xlabel("Round trips kept in the partial sum, N");
    ylabel("|E_{trans}^{(N)}/E_{in} - t_1 t_2/(1-g)| (on resonance)");
    title("Higher finesse needs more round trips to converge");
    legend("Location", "southwest");

    exportReportFigure(picDir, "geometric-series-convergence.pdf");
end

function err = partialSumError(cavity, detuningHz, roundTripCounts)
    exact = cavity.transmissionCoefficient(detuningHz);
    terms = cavity.getRoundTripTransmissionTerms(detuningHz, max(roundTripCounts));
    cumulativePartials = cumsum(terms);
    err = abs(cumulativePartials(roundTripCounts) - exact);
end

function exportSidebandRegimesFigure(picDir)
    % Carrier + sideband field amplitudes J_l(beta) as vertical lines vs.
    % sideband order, one panel per ExampleModulationRegimes value, in
    % ascending beta order -- shows the amplitude scaling with modulation
    % depth directly as a small-multiples comparison, including the
    % carrier-null special case where the carrier stem vanishes entirely.
    regimeValues = [ExampleModulationRegimes.UnderModulated, ExampleModulationRegimes.Optimal, ...
        ExampleModulationRegimes.OverModulated, ExampleModulationRegimes.CarrierNull];
    regimeNames = ["Under-modulated", "Optimal", "Over-modulated", "Carrier null"];
    maxOrder = 3;
    carrierColor = [0.1 0.6 0.1];
    sidebandColor = [0.00 0.45 0.74];

    figure("Name", "Sideband amplitude regimes", "Position", [100 100 900 750]);
    tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");
    for k = 1:numel(regimeValues)
        beta = regimeValues(k);
        sidebands = generatePhaseModulationSidebands(beta, MaxOrder=maxOrder);
        isCarrier = sidebands.Order == 0;

        ax = nexttile;
        hold(ax, "on");
        grid(ax, "on");
        stem(ax, sidebands.Order(~isCarrier), sidebands.Amplitude(~isCarrier), "filled", ...
            "Color", sidebandColor, "LineWidth", 1.5, "DisplayName", "Sidebands");
        stem(ax, sidebands.Order(isCarrier), sidebands.Amplitude(isCarrier), "filled", ...
            "Color", carrierColor, "LineWidth", 2, "DisplayName", "Carrier");
        yline(ax, 0, "Color", [0.5 0.5 0.5], "HandleVisibility", "off");
        xlim(ax, [-maxOrder-0.5, maxOrder+0.5]);
        ylim(ax, [-1.05, 1.05]);
        xlabel(ax, "Sideband order $\ell$ (frequency $\ell f_m$ from carrier)", "Interpreter", "latex");
        ylabel(ax, "$J_\ell(\beta)$", "Interpreter", "latex");
        title(ax, sprintf("%s: $\\beta=%.3f$, $J_0J_1=%.3f$", regimeNames(k), beta, besselj(0,beta)*besselj(1,beta)), "Interpreter", "latex");
        if k == 1
            legend(ax, "Location", "southoutside");
        end
    end

    exportReportFigure(picDir, "sideband-regimes.pdf");
end

function exportPhasorSnapshotFigure(picDir)
    % Static stand-in for animatePhaseModulatedPhasors: four snapshots
    % across one modulation cycle, since print can't show the animation.
    % Uses the project's running example (report.tex \S2.3/\S2.4), which
    % is ExampleModulationRegimes.Optimal itself, so the ell=0,+-1
    % truncation error is large enough to see clearly in the plot.
    modulationIndex = ExampleModulationParameters.ModulationIndex;
    sidebands = generatePhaseModulationSidebands(modulationIndex);
    carrierAmplitude = PhasorMath.sidebandAmplitude(sidebands, 0);
    upperAmplitude = PhasorMath.sidebandAmplitude(sidebands, 1);
    lowerAmplitude = PhasorMath.sidebandAmplitude(sidebands, -1);

    fractionsOfCycle = [0, 0.125, 0.25, 0.375];
    maxRadius = max(1, sum(abs(sidebands.Amplitude))) * 1.15;

    figure("Name", "Phasor snapshots", "Position", [100 100 900 900]);
    tiledlayout(2, 2);
    for k = 1:numel(fractionsOfCycle)
        theta = 2*pi*fractionsOfCycle(k);
        upperVec = upperAmplitude * exp(1i*theta);
        lowerVec = lowerAmplitude * exp(-1i*theta);
        resultant = carrierAmplitude + upperVec + lowerVec;
        ideal = exp(1i*modulationIndex*sin(theta));

        ax = nexttile;
        axis(ax, "equal");
        xlim(ax, [-maxRadius, maxRadius]);
        ylim(ax, [-maxRadius, maxRadius]);
        grid(ax, "on");
        hold(ax, "on");
        circleTheta = linspace(0, 2*pi, 200);
        plot(ax, cos(circleTheta), sin(circleTheta), ":", "Color", [0.75 0.75 0.75], ...
            "LineWidth", 1, "DisplayName", "Unit circle (ideal locus)");
        quiver(ax, 0, 0, real(carrierAmplitude), imag(carrierAmplitude), 0, ...
            "Color", [0.1 0.6 0.1], "LineWidth", 2, "MaxHeadSize", 0.5, "DisplayName", "Carrier");
        quiver(ax, real(carrierAmplitude), imag(carrierAmplitude), real(upperVec), imag(upperVec), 0, ...
            "Color", [0.2 0.4 0.9], "LineWidth", 2, "MaxHeadSize", 0.5, "DisplayName", "Upper sideband");
        quiver(ax, real(carrierAmplitude), imag(carrierAmplitude), real(lowerVec), imag(lowerVec), 0, ...
            "Color", [0.9 0.3 0.2], "LineWidth", 2, "MaxHeadSize", 0.5, "DisplayName", "Lower sideband");
        quiver(ax, 0, 0, real(resultant), imag(resultant), 0, ...
            "Color", [0 0 0], "LineWidth", 2.5, "MaxHeadSize", 0.3, "DisplayName", "Resultant");
        plot(ax, [0, real(ideal)], [0, imag(ideal)], "--", "Color", [0.3 0.3 0.3], "DisplayName", "Ideal phasor");
        xlabel(ax, "Re");
        ylabel(ax, "Im");
        title(ax, sprintf("\\omega_m t / 2\\pi = %.3g", fractionsOfCycle(k)));
        if k == 1
            legend(ax, "Location", "southoutside");
        end
    end

    exportReportFigure(picDir, "phasor-snapshots.pdf");
end

function exportIqModulatorSchematicFigure(picDir)
    % Block-diagram schematic of a dual-parallel Mach-Zehnder IQ
    % modulator (report.tex \S2.5): input light splits into an I-arm and
    % a Q-arm, each carrying its own child Mach-Zehnder intensity
    % modulator (bias + RF-in ports drawn explicitly, since the point of
    % this figure is to show what "bias" and "RF in" physically are),
    % the Q-arm then passes through a third, independently trimmable
    % bias theta_IQ (nominally 90 degrees, but electrically trimmed to
    % compensate the parent combiner's own manufacturing tolerance) before
    % the two arms recombine. Built on the SchematicDiagram library
    % (source/SchematicDiagram) for the boxes/junctions/waveguides; the
    % E_in/E_out edge labels and the 5 bias-voltage arrows are drawn
    % directly rather than through the library, since each is a
    % dangling annotation (a label past the diagram's edge, or an arrow
    % pointing into a box from outside the diagram) rather than a
    % connection between two diagram elements. Each waveguide from the
    % beamsplitter/combiner junction to its arm's child MZM is drawn as
    % a single connection colored by that arm throughout, rather than
    % switching color partway at the bend -- a deliberate simplification
    % over the original hand-drawn version, which does not affect the
    % information the figure conveys.
    lineColor = [0.15 0.15 0.15];
    iColor = [0.20 0.40 0.90];
    qColor = [0.90 0.30 0.20];
    biasColor = [0.35 0.35 0.35];
    waveguideWidth = 2;

    figure("Name", "IQ modulator schematic", "Position", [100 100 1100 550]);
    ax = axes;
    hold(ax, "on");
    axis(ax, "equal");
    axis(ax, "off");

    diagram = SchematicDiagram();
    splitter = diagram.addJunction([1.5 3]);
    combiner = diagram.addJunction([9.5 3]);
    mzmI = diagram.addBox([5.25 4.5], 2.5, 1, Label="Child MZM ($I$)", EdgeColor=iColor);
    mzmQ = diagram.addBox([5.25 1.5], 2.5, 1, Label="Child MZM ($Q$)", EdgeColor=qColor);
    phaseBias = diagram.addBox([7.5 1.5], 1, 0.6, Label="$\theta_{\mathrm{IQ}}$", ...
        Color=[0.95 0.95 0.95], CornerRadius=0.3, EdgeColor=biasColor);

    % Dangling leads at the diagram's edges: constructed directly (not
    % via diagram.addJunction), so they never get drawn -- they exist
    % purely to anchor a connection endpoint.
    leadIn = SchematicJunction([0 3]);
    leadOut = SchematicJunction([11 3]);

    diagram.addConnection(leadIn, ConnectorSide.East, splitter, ConnectorSide.West, ...
        Color=lineColor, LineWidth=waveguideWidth);
    diagram.addConnection(splitter, ConnectorSide.North, mzmI, ConnectorSide.West, ...
        Waypoints=[2.5 4.5], Color=iColor, LineWidth=waveguideWidth);
    diagram.addConnection(splitter, ConnectorSide.South, mzmQ, ConnectorSide.West, ...
        Waypoints=[2.5 1.5], Color=qColor, LineWidth=waveguideWidth);
    diagram.addConnection(mzmI, ConnectorSide.East, combiner, ConnectorSide.North, ...
        Waypoints=[8 4.5], Color=iColor, LineWidth=waveguideWidth);
    diagram.addConnection(mzmQ, ConnectorSide.East, phaseBias, ConnectorSide.West, ...
        Color=qColor, LineWidth=waveguideWidth);
    diagram.addConnection(phaseBias, ConnectorSide.East, combiner, ConnectorSide.South, ...
        Waypoints=[8.5 1.5], Color=qColor, LineWidth=waveguideWidth);
    diagram.addConnection(combiner, ConnectorSide.East, leadOut, ConnectorSide.West, ...
        Color=lineColor, LineWidth=waveguideWidth);

    diagram.draw(ax);

    text(ax, -0.3, 3, "$E_{\mathrm{in}}(t)$", "Interpreter", "latex", "FontSize", 12, "HorizontalAlignment", "right");
    text(ax, 11.2, 3, "$E_{\mathrm{out}}(t)=E_0\left[s_I(t)+i\,s_Q(t)\right]e^{i\omega_{\mathrm{laser}}t}$", ...
        "Interpreter", "latex", "FontSize", 12, "HorizontalAlignment", "left");

    drawIqSchematicBiasArrow(ax, 4.7, 4, "$V_{\pi,I}$" + newline + "(bias)", biasColor);
    drawIqSchematicBiasArrow(ax, 5.8, 4, "$v_I(t)$" + newline + "(RF in)", iColor);
    drawIqSchematicBiasArrow(ax, 4.7, 1, "$V_{\pi,Q}$" + newline + "(bias)", biasColor);
    drawIqSchematicBiasArrow(ax, 5.8, 1, "$v_Q(t)$" + newline + "(RF in)", qColor);
    drawIqSchematicBiasArrow(ax, 7.5, 1, "$\theta_{\mathrm{IQ}}\approx90^\circ$" + newline + "(bias, trim)", biasColor);

    xlim(ax, [-0.5, 12.5]);
    ylim(ax, [0.3, 5.7]);

    exportReportFigure(picDir, "iq-modulator-schematic.pdf");
end

function drawIqSchematicBiasArrow(ax, x, yBase, label, color)
    quiver(ax, x, yBase-0.9, 0, 0.8, 0, "Color", color, "LineWidth", 1.3, "MaxHeadSize", 0.8);
    text(ax, x, yBase-1.1, label, "Interpreter", "latex", "FontSize", 9, ...
        "HorizontalAlignment", "center", "VerticalAlignment", "top", "Color", color);
end

function exportIqModulatorSpectrumFigure(picDir)
    % Top panel: the two drive signals generateIqModulatorDrive produces
    % at the project's running example (matching \S2.2/\S2.4's worked
    % numbers, since the running example is ExampleModulationRegimes.Optimal
    % itself) -- a DC bias and a single RF tone, nothing else. Bottom
    % panel: the resulting spectrum, recovered by an exact one-cycle FFT
    % (not assumed/hand-set to zero away from ell=0,+-1 -- computed the
    % same way generateIqModulatorDriveTest.m verifies it), contrasted
    % against Figure 3's EOM spectrum at the same beta, which always has
    % nonzero higher-order bars.
    modulationIndex = ExampleModulationParameters.ModulationIndex;
    modulationFrequencyHz = ExampleModulationParameters.ModulationFrequencyHz;
    maxOrder = 3;
    samplesPerCycle = 64;

    tCycle = linspace(0, 1/modulationFrequencyHz, 400);
    [inPhase, quadrature] = generateIqModulatorDrive(modulationIndex, modulationFrequencyHz, tCycle);

    tHarm = (0:samplesPerCycle-1) / samplesPerCycle / modulationFrequencyHz;
    [inPhaseHarm, quadratureHarm] = generateIqModulatorDrive(modulationIndex, modulationFrequencyHz, tHarm);
    envelope = inPhaseHarm + 1i*quadratureHarm;
    harmonics = fft(envelope) / samplesPerCycle;
    orders = -maxOrder:maxOrder;
    binIndex = mod(orders, samplesPerCycle) + 1;
    harmonicAmplitude = harmonics(binIndex);

    figure("Name", "IQ modulator drive and exact spectrum", "Position", [100 100 900 700]);
    tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

    ax1 = nexttile;
    hold(ax1, "on");
    grid(ax1, "on");
    plot(ax1, tCycle*1e9, inPhase, "-", "Color", [0.20 0.40 0.90], "LineWidth", 2, "DisplayName", "$s_I(t)$ (DC bias)");
    plot(ax1, tCycle*1e9, quadrature, "-", "Color", [0.90 0.30 0.20], "LineWidth", 2, "DisplayName", "$s_Q(t)$ (single RF tone)");
    xlabel(ax1, "$t$ (ns)", "Interpreter", "latex");
    ylabel(ax1, "Drive amplitude", "Interpreter", "latex");
    legend(ax1, "Interpreter", "latex", "Location", "eastoutside");
    title(ax1, "IQ modulator drive signals");

    ax2 = nexttile;
    hold(ax2, "on");
    grid(ax2, "on");
    stem(ax2, orders, abs(harmonicAmplitude), "filled", "Color", [0.1 0.6 0.1], "LineWidth", 1.5);
    yline(ax2, 0, "Color", [0.5 0.5 0.5], "HandleVisibility", "off");
    xlim(ax2, [-maxOrder-0.5, maxOrder+0.5]);
    xlabel(ax2, "Sideband order $\ell$", "Interpreter", "latex");
    ylabel(ax2, "$|c_\ell|$", "Interpreter", "latex");
    title(ax2, sprintf("Resulting spectrum -- exactly zero for $|\\ell|\\geq2$ (max: %.1e)", ...
        max(abs(harmonicAmplitude(abs(orders) >= 2)))), "Interpreter", "latex");

    exportReportFigure(picDir, "iq-modulator-spectrum.pdf");
end

function exportPhasorChainConceptualFigure(cavity, picDir)
    % Six snapshots of the round-trip phasor chain (same construction as
    % animateCavityRoundTripPhasors.m), for the report's running-example
    % cavity (FSR = 1 GHz, Finesse = 1000, same as Figure 2), illustrating
    % the "what destructively interferes with what" argument: on
    % resonance, a small detuning either side (expressed as a fraction of
    % this cavity's own linewidth, since at Finesse=1000 the resonance is
    % only ~0.36 degrees of round-trip phase wide -- fixed absolute
    % degrees like +-30/+-90 would all land far outside it and look
    % identical), and the 180-degree anti-resonance point (universal,
    % independent of finesse). Because this cavity needs ~thousands of
    % round trips to converge (see the Finesse=1000 curve in Figure 1),
    % the leaked-out buildup is drawn as a smooth spiral rather than a
    % hand-countable chain of arrows -- unlike the low-finesse toy used
    % earlier for animateCavityRoundTripPhasors.m's live animation. The
    % prompt reflection (direct bounce off the front mirror, -r1) and the
    % cavity's leaked-out buildup (the geometric series of round trips)
    % are drawn in different colors to make the two-term cancellation
    % structure of Eq. (5) visible directly.
    numRoundTrips = 3000;

    lw = cavity.LinewidthFWHM;
    detuningsHz = [0, 0.5*lw, -0.5*lw, 1.5*lw, -1.5*lw, 0.5*cavity.FSR];
    promptTerm = cavity.getPromptReflectionCoefficient();
    allEchoTerms = cavity.getRoundTripEchoTerms(detuningsHz, numRoundTrips);
    panelLabels = 'abcdef';
    panelTags = ["\Delta f_{detune} = 0", ...
                 "\Delta f_{detune} = +0.5\Delta\nu_{FWHM}", ...
                 "\Delta f_{detune} = -0.5\Delta\nu_{FWHM}", ...
                 "\Delta f_{detune} = +1.5\Delta\nu_{FWHM}", ...
                 "\Delta f_{detune} = -1.5\Delta\nu_{FWHM}", ...
                 "\Delta f_{detune} = FSR/2 (180^\circ)"];
    promptColor = [0.85 0.33 0.10];
    leakageColor = [0.00 0.45 0.74];

    figure("Name", "Round-trip phasor chain at fixed detunings", "Position", [100 100 950 650]);
    tiledlayout(2, 3, "TileSpacing", "compact", "Padding", "compact");
    for k = 1:numel(detuningsHz)
        detuningHz = detuningsHz(k);
        chainTips = [promptTerm, promptTerm + cumsum(allEchoTerms(:, k)).'];
        points = [0, chainTips];
        exactValue = cavity.reflectionCoefficient(detuningHz);

        ax = nexttile;
        axis(ax, "equal");
        xlim(ax, [-1.1, 1.1]);
        ylim(ax, [-1.1, 1.1]);
        grid(ax, "on");
        hold(ax, "on");
        plot(ax, real(points(1:2)), imag(points(1:2)), "-o", "Color", promptColor, ...
            "LineWidth", 2.5, "MarkerSize", 4, "DisplayName", "Prompt reflection -r_1");
        plot(ax, real(points(2:end)), imag(points(2:end)), "-", "Color", leakageColor, ...
            "LineWidth", 1.2, "DisplayName", "Cavity leakage (round trips)");
        plot(ax, real(exactValue), imag(exactValue), "kx", "MarkerSize", 12, "LineWidth", 1.5, ...
            "DisplayName", "Total reflection (sum)");
        xlabel(ax, "Re");
        ylabel(ax, "Im");
        title(ax, sprintf("(%s) %s\n|r|^2 = %.3f", panelLabels(k), panelTags(k), abs(exactValue)^2));
        if k == 1
            legend(ax, "Location", "southoutside");
        end
    end

    exportReportFigure(picDir, "phasor-chain-conceptual.pdf");
end

function exportPdhDetectionChainSchematicFigure(picDir)
    % Block-diagram schematic of the full PDH laser-locking setup
    % (report.tex \S3.1): laser, a generic phase modulator (either \S2.2's
    % EOM or \S2.5's IQ modulator can fill this role -- the detection
    % chain's own math never depends on which one produced the sidebands),
    % cavity, photodiode/mixer/low-pass-filter detection chain, and the LO
    % distribution (straight to the modulator, phase-shifted by
    % theta_demod into the mixer). The servo/PZT feedback path back to the
    % laser is drawn but greyed out and labeled "not modeled" -- this
    % project's destination is the frequency-domain error signal alone,
    % not closed-loop locking (that is a separate, phase-2 wayfinder map).
    % Built on the SchematicDiagram library (source/SchematicDiagram);
    % the "beamsplitter"/"RF in" labels and the "servo + PZT" banner are
    % drawn directly rather than as connection labels, since each sits
    % beside its line rather than centered on it (the "RF in" label in
    % particular must dodge the oscillator/phase-shift/mixer column
    % beside it, which the library's own auto-placement doesn't know
    % about) or isn't attached to a connection at all.
    %
    % Layout reads as a loop rather than a left-to-right chain: the
    % forward optical path runs laser -> modulator -> cavity, left to
    % right, ending at the cavity. Directly beneath the modulator hangs a
    % single LO stack (mixer, its demod phase shifter, then the
    % oscillator), feeding the modulator's RF input upward and the
    % mixer's LO input downward with no crossing wires. The photodiode
    % (under the beamsplitter) feeds the mixer, then the LPF, running
    % right-to-left back to a column above the laser; the LPF's own
    % output climbs straight up into the laser from below as the
    % (greyed-out, unmodeled) servo/PZT feedback, labeled with the error
    % signal it would carry. Every connection below is a straight line
    % between two exactly-facing connectors -- this layout was chosen (by
    % hand, before this library existed) so that no connection needs an
    % explicit bend.
    lineColor = [0.15 0.15 0.15];
    feedbackColor = [0.6 0.6 0.6];

    figure("Name", "PDH detection chain schematic", "Position", [80 80 1250 700]);
    ax = axes;
    hold(ax, "on");
    axis(ax, "equal");
    axis(ax, "off");

    diagram = SchematicDiagram();
    laser = diagram.addBox([0.7 6], 1.0, 0.45, Label="Laser");
    modulator = diagram.addBox([2.7 6], 1.4, 0.45, Label="Phase" + newline + "Modulator");
    cavity = diagram.addBox([6.9 6], 1.4, 0.45, Label="Cavity");
    pd = diagram.addBox([4.6 3], 1.2, 0.45, Label="PD");
    mixer = diagram.addBox([2.7 3], 1.4, 0.45, Label="Mixer");
    lpf = diagram.addBox([0.7 3], 1.4, 0.45, Label="LPF");
    phaseShift = diagram.addBox([2.7 4.0], 1.2, 0.45, Label="Phase shift" + newline + "$\theta_{\mathrm{demod}}$");
    oscillator = diagram.addBox([2.7 5.0], 1.4, 0.45, Label="Oscillator" + newline + "($f_m$)");
    beamsplitter = diagram.addJunction([4.6 6]);

    % Forward optical path: laser -> modulator -> beamsplitter -> cavity.
    diagram.addConnection(laser, ConnectorSide.East, modulator, ConnectorSide.West, Color=lineColor);
    diagram.addConnection(modulator, ConnectorSide.East, beamsplitter, ConnectorSide.West, Color=lineColor);
    diagram.addConnection(beamsplitter, ConnectorSide.East, cavity, ConnectorSide.West, Color=lineColor);

    % Reflected pick-off drops straight down into the PD, which sits
    % directly under the beamsplitter.
    diagram.addConnection(beamsplitter, ConnectorSide.South, pd, ConnectorSide.North, ...
        Color=lineColor, LineEnds=ConnectionEnds.Arrow);

    % Detection chain runs right-to-left: PD -> Mixer -> LPF, ending in a
    % column directly above the laser.
    diagram.addConnection(pd, ConnectorSide.West, mixer, ConnectorSide.East, ...
        Color=lineColor, LineEnds=ConnectionEnds.Arrow);
    diagram.addConnection(mixer, ConnectorSide.West, lpf, ConnectorSide.East, ...
        Color=lineColor, LineEnds=ConnectionEnds.Arrow);

    % LO stack: mixer, demod phase shifter, oscillator, all sharing the
    % modulator's x position directly above. The oscillator drives the
    % modulator's RF input upward and, through the phase shifter, the
    % mixer's LO input downward -- both in a straight line, since nothing
    % else occupies this column.
    diagram.addConnection(phaseShift, ConnectorSide.South, mixer, ConnectorSide.North, ...
        Color=lineColor, LineEnds=ConnectionEnds.Arrow);
    diagram.addConnection(oscillator, ConnectorSide.South, phaseShift, ConnectorSide.North, ...
        Color=lineColor, LineEnds=ConnectionEnds.Arrow);
    diagram.addConnection(oscillator, ConnectorSide.North, modulator, ConnectorSide.South, ...
        Color=lineColor, LineEnds=ConnectionEnds.Arrow);

    % Servo/PZT feedback (not modeled) closes the loop from the LPF's
    % error signal straight up into the laser, entering from below.
    diagram.addConnection(lpf, ConnectorSide.North, laser, ConnectorSide.South, ...
        Color=feedbackColor, LineStyle="--", LineEnds=ConnectionEnds.Arrow, ...
        Label="Error signal $\varepsilon$", LabelPosition=[0.85 3.9]);

    diagram.draw(ax);

    text(ax, 4.85, 5.75, "beamsplitter", "FontSize", 8, "HorizontalAlignment", "left", "Color", lineColor);
    text(ax, 1.9, 5.5, "RF in", "FontSize", 8, "HorizontalAlignment", "right", "Color", lineColor);
    text(ax, 0.7, 6.8, "servo + PZT (not modeled --- see phase 2)", ...
        "FontSize", 9, "HorizontalAlignment", "center", "Color", feedbackColor);

    xlim(ax, [-0.6, 8.3]);
    ylim(ax, [2.0, 7.3]);

    exportReportFigure(picDir, "pdh-detection-chain-schematic.pdf");
end

function spans = pdhPhotodiodeScanSpans(setup)
    % Single source of truth for the three named detuning windows shown in
    % both exportPhotodiodePowerScanFigure (time domain) and
    % exportPdhDemodulatedSignalsFigure (frequency domain) -- both read
    % spans from here, never hardcode their own copy, so a future change to
    % any width or center can never leave the two figures showing
    % mismatched ranges.
    cavity = setup.Cavity;
    modulationFrequencyHz = setup.ModulationFrequencyHz;
    wideSpanInLinewidths = 2 * 1.3 * modulationFrequencyHz / cavity.LinewidthFWHM;
    zoomSpanInLinewidths = 6;  % +-3 linewidths

    spans = struct( ...
        "Name", {"full", "carrier resonance", "sideband resonance"}, ...
        "CenterDetuningHz", {0, 0, -modulationFrequencyHz}, ...
        "ScanSpanInLinewidths", {wideSpanInLinewidths, zoomSpanInLinewidths, zoomSpanInLinewidths});
end

function exportPhotodiodePowerScanFigure(picDir)
    % report.tex \S3.2 ("From reflected field to photodiode power"):
    % P_PD,DC(t)/P_PD,omega_m(t)/P_PD,2omega_m(t) and their sum, as the
    % carrier (and its sidebands) scan across resonance. Three columns --
    % pdhPhotodiodeScanSpans's shared spans -- a full +-1.3*f_m overview
    % (a dense oscillation blob is expected there; it shows only the slow
    % envelope) plus a genuine time-domain zoom on the carrier resonance
    % and on a sideband resonance, narrow enough (+-0.5 linewidth) to
    % actually resolve individual oscillation cycles. Fixes the earlier
    % 2-row (zoom-detuning-span/wide-detuning-span) layout, where every
    % panel's time axis spanned the whole multi-us scan and no oscillation
    % was ever resolvable regardless of which detuning span was shown.
    % Each column's time axis is referenced to t=0 at that column's own
    % resonance, not the scan's start.
    %
    % Deliberately shows no demodulated/downmixed content -- that lives in
    % exportPdhDemodulatedSignalsFigure instead, placed after \S3.4 derives
    % epsilon (Eq. 29), so this figure never has to forward-reference a
    % quantity not yet derived at this point in the report.
    %
    % Bespoke to the report (the general demo is
    % plotReflectedPowerFrequencyScan.m): adds the carrier/sidebands DC
    % split (why the DC dip doesn't reach zero) and dotted markers at every
    % resonance visible within each column's span. plotPdhSignalPanel's
    % ExtraCurves is a general overlay hook -- a future downmixed companion
    % curve could be added at a call site here, "in the same style", without
    % changing the panel-drawing code itself (see the underlying wayfinder
    % map).
    cavity = ExampleCavities.CriticalHighFinesse;
    sidebands = generatePhaseModulationSidebands(ExampleModulationParameters.ModulationIndex);
    modulationFrequencyHz = ExampleModulationParameters.ModulationFrequencyHz;
    setup = PdhMeasurementSetup(cavity, sidebands, modulationFrequencyHz);
    spans = pdhPhotodiodeScanSpans(setup);
    resonancesOfInterestHz = [0, -modulationFrequencyHz, modulationFrequencyHz];
    numSpans = numel(spans);

    figure("Name", "Photodiode power under a resonance scan", "Position", [60 60 1200 900]);
    tiledlayout(4, numSpans, "TileSpacing", "compact", "Padding", "compact");

    for s = 1:numSpans
        span = spans(s);
        [t, detuning, ~, dc, atOmega, atTwoOmega, carrierPower, sidebandsPower] = computeReflectedPowerFrequencyScan(setup, ...
            ScanSpanInLinewidths=span.ScanSpanInLinewidths, CenterDetuningHz=span.CenterDetuningHz);
        [~, referenceIdx] = min(abs(detuning - span.CenterDetuningHz));
        tUs = (t - t(referenceIdx)) * 1e6;
        markerTimesUs = resonanceMarkerTimesUs(t, detuning, span.CenterDetuningHz, resonancesOfInterestHz);

        plotPdhSignalPanel(nexttile(s), tUs, dc, ...
            XLabel="Time ($\mu$s)", YLabel="$P_{\mathrm{PD,DC}}(t)$ (a.u.)", ...
            Title=sprintf("DC term (%s)", span.Name), ResonanceMarkers=markerTimesUs, ShowLegend=(s == 1), ...
            ExtraCurves={{carrierPower, "--", "carrier only"}, {sidebandsPower, ":", "sidebands only"}});

        plotPdhSignalPanel(nexttile(numSpans + s), tUs, atOmega, ...
            XLabel="Time ($\mu$s)", YLabel="$P_{\mathrm{PD},\omega_m}(t)$ (a.u.)", ...
            Title=sprintf("\\omega_m term (%s)", span.Name), ResonanceMarkers=markerTimesUs);

        plotPdhSignalPanel(nexttile(2*numSpans + s), tUs, atTwoOmega, ...
            XLabel="Time ($\mu$s)", YLabel="$P_{\mathrm{PD,2}\omega_m}(t)$ (a.u.)", ...
            Title=sprintf("2\\omega_m term (%s)", span.Name), ResonanceMarkers=markerTimesUs);

        % Sum's own y-range is exempt from the shared [-1,1] convention:
        % coherent addition of the three lines' fields (all derived from
        % the same laser, phase-locked through one modulator) lets the
        % instantaneous total power exceed the incoherent sum of their
        % individual powers, peaking near 1.86 for this running example --
        % physically correct, not a bug (see ticket 14's amplitude
        % verification), but it would be clipped by [-1,1].
        plotPdhSignalPanel(nexttile(3*numSpans + s), tUs, dc + atOmega + atTwoOmega, ...
            XLabel="Time ($\mu$s)", YLabel="$P_{\mathrm{PD}}(t)$ (a.u.)", ...
            Title=sprintf("Sum (%s)", span.Name), ResonanceMarkers=markerTimesUs, YLim=[0, 2]);
    end

    exportReportFigure(picDir, "pdh-photodiode-power-scan.pdf", ContentType="image");
end

function exportPdhDemodulatedSignalsFigure(picDir)
    % Frequency-domain companion to exportPhotodiodePowerScanFigure,
    % sharing the exact same three named spans via pdhPhotodiodeScanSpans
    % so the two figures' x-ranges can never silently drift apart after a
    % future change to either one. Shows P_PD,DC(Delta f), the demodulated
    % error signal epsilon(Delta f), and its 2*omega_m counterpart
    % zeta(Delta f) -- report.tex \S3.4, placed after both are actually
    % derived, unlike exportPhotodiodePowerScanFigure, which deliberately
    % shows no demodulated content to avoid forward-referencing them.
    cavity = ExampleCavities.CriticalHighFinesse;
    sidebands = generatePhaseModulationSidebands(ExampleModulationParameters.ModulationIndex);
    modulationFrequencyHz = ExampleModulationParameters.ModulationFrequencyHz;
    setup = PdhMeasurementSetup(cavity, sidebands, modulationFrequencyHz);
    spans = pdhPhotodiodeScanSpans(setup);
    resonancesOfInterestHz = [0, -modulationFrequencyHz, modulationFrequencyHz];
    numSpans = numel(spans);

    figure("Name", "Demodulated signals across matched spans", "Position", [60 60 1200 700]);
    tiledlayout(3, numSpans, "TileSpacing", "compact", "Padding", "compact");

    for s = 1:numSpans
        span = spans(s);
        % A plain linspace, not computeReflectedPowerFrequencyScan's
        % oscillation-resolving sample density (tens of thousands of
        % points, needed only for the time-domain figure): every curve
        % here is smooth in detuning, so 1001 points is already
        % overkill for the plot, and reusing the finer grid was
        % bloating this vector PDF to >1MB for no visual benefit.
        halfSpanHz = span.ScanSpanInLinewidths/2 * cavity.LinewidthFWHM;
        detuning = linspace(span.CenterDetuningHz - halfSpanHz, span.CenterDetuningHz + halfSpanHz, 1001);
        reflectionAtLines = cavity.reflectionCoefficient(detuning + sidebands.Order*modulationFrequencyHz);
        dc = sum(sidebands.Amplitude.^2 .* abs(reflectionAtLines).^2, 1);
        errorSignal = computePdhErrorSignalDotProduct(setup, detuning);
        zeta = computePdh2OmegaSignalDotProduct(setup, detuning);
        detuningMHz = detuning / 1e6;
        markersMHz = resonanceMarkerMHz(detuning, resonancesOfInterestHz);

        plotPdhSignalPanel(nexttile(s), detuningMHz, dc, ...
            XLabel="$\Delta f_{\mathrm{detune}}$ (MHz)", YLabel="$P_{\mathrm{PD,DC}}$ (a.u.)", ...
            Title=sprintf("DC term (%s)", span.Name), ResonanceMarkers=markersMHz);

        plotPdhSignalPanel(nexttile(numSpans + s), detuningMHz, errorSignal, ...
            XLabel="$\Delta f_{\mathrm{detune}}$ (MHz)", YLabel="$\varepsilon$ (a.u.)", ...
            Title=sprintf("Error signal (%s)", span.Name), ResonanceMarkers=markersMHz);

        plotPdhSignalPanel(nexttile(2*numSpans + s), detuningMHz, zeta, ...
            XLabel="$\Delta f_{\mathrm{detune}}$ (MHz)", YLabel="$\zeta$ (a.u.)", ...
            Title=sprintf("2\\omega_m signal (%s)", span.Name), ResonanceMarkers=markersMHz);
    end

    exportReportFigure(picDir, "pdh-demodulated-signals-spans.pdf");
end

function plotPdhSignalPanel(ax, x, curve, opts)
    % Shared panel drawer for both exportPhotodiodePowerScanFigure (x =
    % time) and exportPdhDemodulatedSignalsFigure (x = detuning): one
    % primary curve, dotted resonance markers, and an ExtraCurves overlay
    % hook drawn in the same style -- today's carrier/sidebands DC split,
    % and later, potentially, a downmixed companion curve -- so adding one
    % is a call-site change, not a panel-drawing rewrite.
    arguments
        ax
        x (1,:) double
        curve (1,:) double
        opts.XLabel (1,1) string
        opts.YLabel (1,1) string
        opts.Title (1,1) string
        opts.ResonanceMarkers (1,:) double = []
        opts.ExtraCurves (1,:) cell = {}
        opts.ShowLegend (1,1) logical = false
        opts.YLim (1,2) double = [-1, 1]
    end
    hold(ax, "on");
    plot(ax, x, curve, "DisplayName", opts.YLabel);
    for k = 1:numel(opts.ExtraCurves)
        entry = opts.ExtraCurves{k};
        plot(ax, x, entry{1}, entry{2}, "DisplayName", entry{3});
    end
    for k = 1:numel(opts.ResonanceMarkers)
        xline(ax, opts.ResonanceMarkers(k), ":", "Color", [0.5 0.5 0.5], "HandleVisibility", "off");
    end
    xlabel(ax, opts.XLabel, "Interpreter", "latex");
    ylabel(ax, opts.YLabel, "Interpreter", "latex");
    title(ax, opts.Title, "Interpreter", "tex");
    ylim(ax, opts.YLim);
    if opts.ShowLegend
        legend(ax, "Interpreter", "latex", "Location", "south", "FontSize", 7);
    end
end

function markerTimesUs = resonanceMarkerTimesUs(t, detuning, referenceDetuningHz, candidateDetuningsHz)
    [~, referenceIdx] = min(abs(detuning - referenceDetuningHz));
    inRange = candidateDetuningsHz >= min(detuning) & candidateDetuningsHz <= max(detuning);
    markerTimesUs = (interp1(detuning, t, candidateDetuningsHz(inRange)) - t(referenceIdx)) * 1e6;
end

function markersMHz = resonanceMarkerMHz(detuning, candidateDetuningsHz)
    inRange = candidateDetuningsHz >= min(detuning) & candidateDetuningsHz <= max(detuning);
    markersMHz = candidateDetuningsHz(inRange) / 1e6;
end


function exportPdhResonanceCaseWalkthroughFigure(picDir)
    % Image, not the default vector: 16 axes x thousands-of-sample curves
    % balloons a vector PDF (~500KB) for no visible fidelity gain at
    % rendering resolution -- same tradeoff exportPhotodiodePowerScanFigure
    % already made for its own dense curves.
    plotPdhResonanceCaseWalkthrough();
    exportReportFigure(picDir, "pdh-resonance-case-walkthrough.pdf", ContentType="image");
end

function exportPdhResonanceCaseWalkthroughAbsorptionFigure(picDir)
    % Q phase (theta=0), not the dispersive default of pi/2: at pi/2 the
    % amplitude-only response's dot product is identically zero everywhere
    % (Z is always real, W always imaginary there).
    plotPdhResonanceCaseWalkthrough(AmplitudeOnly=true, DemodulationPhase=0);
    exportReportFigure(picDir, "pdh-resonance-case-walkthrough-absorption.pdf", ContentType="image");
end

function exportCouplingRegimesFigure(picDir)
    % The "resonance circle": as detuning sweeps across one full FSR, the
    % reflection coefficient r(phi) traces an exact circle in the complex
    % plane (a Moebius transform of the unit circle e^{i phi}). Whether
    % that circle encloses the origin -- not whether it merely comes
    % close -- is what distinguishes over- from under-coupling; critical
    % coupling is the boundary case where the circle passes exactly
    % through the origin. Swapping which mirror is "input" vs "back"
    % swaps under- for over-coupled while leaving Finesse (which depends
    % only on the product r1*r2) unchanged. The on-resonance point is
    % decomposed into the same two color-coded contributions as
    % exportPhasorChainConceptualFigure: orange for the prompt reflection
    % -r1, blue for the total reflected field it sums to (the leaked-out
    % buildup's net contribution, without drawing each round trip).
    underCoupled = ExampleCavities.UndercoupledHighFinesse;
    critical = ExampleCavities.CriticalHighFinesse;
    overCoupled = ExampleCavities.OvercoupledHighFinesse;

    cavities = {underCoupled, critical, overCoupled};
    panelLabels = 'abc';
    panelNames = ["Undercoupled (R_1 > R_2)", "Critically coupled (R_1 = R_2)", "Overcoupled (R_1 < R_2)"];
    circleColor = [0.00 0.45 0.74];
    promptColor = [0.85 0.33 0.10];
    leakageColor = [0.00 0.45 0.74];

    figure("Name", "Over- and under-coupled resonance circles", "Position", [100 100 1200 430]);
    tiledlayout(1, 3, "TileSpacing", "compact", "Padding", "compact");
    for k = 1:numel(cavities)
        cavity = cavities{k};
        phi = resonanceCircleSamplingGrid(cavity.Finesse);
        detuningHz = phi/(2*pi) * cavity.FSR;
        r = cavity.reflectionCoefficient(detuningHz);
        promptTerm = cavity.getPromptReflectionCoefficient();
        onResonance = cavity.reflectionCoefficient(0);

        ax = nexttile;
        axis(ax, "equal");
        xlim(ax, [-1.1, 1.1]);
        ylim(ax, [-1.1, 1.1]);
        grid(ax, "on");
        hold(ax, "on");
        fill(ax, real(r), imag(r), circleColor, "FaceAlpha", 0.15, "EdgeColor", circleColor, ...
            "LineWidth", 1.5, "DisplayName", "Resonance circle r(\phi)");
        plot(ax, 0, 0, "k+", "MarkerSize", 14, "LineWidth", 2, "DisplayName", "Origin");
        plot(ax, [0, promptTerm], [0, 0], "-o", "Color", promptColor, "LineWidth", 2.5, "MarkerSize", 5, ...
            "MarkerFaceColor", promptColor, "DisplayName", "Prompt reflection -r_1");
        plot(ax, [promptTerm, real(onResonance)], [0, imag(onResonance)], "-o", "Color", leakageColor, ...
            "LineWidth", 1.5, "MarkerSize", 5, "MarkerFaceColor", leakageColor, ...
            "DisplayName", "Total reflection (on resonance)");
        xlabel(ax, "Re");
        ylabel(ax, "Im");
        title(ax, sprintf("(%s) %s\nFinesse=%.0f, min|r|^2=%.3f", ...
            panelLabels(k), panelNames(k), cavity.Finesse, min(abs(r))^2));
        if k == 1
            legend(ax, "Location", "southoutside");
        end
    end

    exportReportFigure(picDir, "coupling-regimes.pdf");
end

function exportCouplingRegimeResponsePlots(picDir)
    % The full cavity-response demo (plotCavityResponse.m) for an explicit
    % undercoupled and overcoupled low-finesse cavity, to see the abstract
    % resonance-circle story (exportCouplingRegimesFigure) play out in the
    % same panel layout as Figure 2. Low finesse is used deliberately: the
    % undercoupled phase's "swoop past the branch cut and turn back"
    % (rather than a full sweep) is only visible within a +-5-linewidth
    % window when the linewidth is a large fraction of the FSR.
    underCoupledLowF = ExampleCavities.UndercoupledLowFinesse;
    overCoupledLowF = ExampleCavities.OvercoupledLowFinesse;

    plotCavityResponse(underCoupledLowF);
    exportReportFigure(picDir, "cavity-response-undercoupled.pdf");

    plotCavityResponse(overCoupledLowF);
    exportReportFigure(picDir, "cavity-response-overcoupled.pdf");
end

function exportReportFigure(picDir, filename, opts)
    % Export the current figure (gcf) as a PDF into picDir and close it.
    % Every export*Figure function ends by calling this -- mirrors
    % source/firecalc/report's IFIREAnalysis.exportFigure, adapted for this
    % file's one-figure-at-a-time, create-then-immediately-export pattern
    % (no explicit figure number needed). Defaults to vector output;
    % figures with hundreds of thousands of oscillation samples (e.g.
    % exportPhotodiodePowerScanFigure) pass ContentType="image" instead --
    % vector fidelity is indistinguishable at rendering resolution there,
    % and the PDF would otherwise balloon.
    arguments
        picDir (1,1) string
        filename (1,1) string
        opts.ContentType (1,1) string {mustBeMember(opts.ContentType, ["vector", "image"])} = "vector"
    end
    exportgraphics(gcf, fullfile(picDir, filename), "ContentType", opts.ContentType);
    close(gcf);
end

function phi = resonanceCircleSamplingGrid(finesse)
    % A uniform grid over one FSR under-resolves the resonance itself
    % once Finesse is more than a few hundred: with the resonance only
    % 2*pi/Finesse wide out of the full 2*pi round-trip phase, a coarse
    % uniform grid only has a couple of samples inside it, so the fitted
    % polygon chord-cuts straight across the sharp bend there instead of
    % tracing it -- turning the true circle into a "pizza slice" wedge.
    % Sample densely near resonance and coarsely everywhere else instead.
    linewidthPhi = 2*pi / finesse;
    fineHalfWidth = min(pi, 30 * linewidthPhi);
    phiFine = linspace(-fineHalfWidth, fineHalfWidth, 4000);
    phiCoarseLeft = linspace(-pi, -fineHalfWidth, 300);
    phiCoarseRight = linspace(fineHalfWidth, pi, 300);
    phi = unique([phiCoarseLeft, phiFine, phiCoarseRight]);
end

function exportCouplingRegimesTable(tableDir)
    % Numeric signature of each coupling regime, over one full FSR: the
    % minimum reflected power reached, and the net reflection-phase change
    % accumulated over one full FSR sweep (0 deg for undercoupled -- the
    % resonance circle does not enclose the origin -- vs 360 deg for
    % critical/overcoupled, where it does).
    cavities = {ExampleCavities.UndercoupledHighFinesse, ...
                ExampleCavities.CriticalHighFinesse, ...
                ExampleCavities.OvercoupledHighFinesse};
    regimeNames = ["Undercoupled", "Critically coupled", "Overcoupled"];

    fid = fopen(fullfile(tableDir, "coupling-regimes.tex"), "w");
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, "\\begin{tabular}{@{}lllllc@{}}\n\\toprule\n");
    fprintf(fid, "Regime & $R_1$ & $R_2$ & Finesse & $\\min|r|^2$ & Net phase / FSR \\\\\n\\midrule\n");
    for k = 1:numel(cavities)
        cavity = cavities{k};
        phi = linspace(-pi, pi, 200001);
        detuningHz = phi/(2*pi) * cavity.FSR;
        r = cavity.reflectionCoefficient(detuningHz);
        netPhaseDeg = rad2deg(unwrap(angle(r)));
        netPhaseDeg = netPhaseDeg(end) - netPhaseDeg(1);
        fprintf(fid, "%s & %.4f & %.4f & %.1f & %.4f & $%.0f^\\circ$ \\\\\n", ...
            regimeNames(k), cavity.InputMirrorPowerReflectivity, cavity.BackMirrorPowerReflectivity, ...
            cavity.Finesse, min(abs(r))^2, netPhaseDeg);
    end
    fprintf(fid, "\\bottomrule\n\\end{tabular}\n");
end

function exportFinesseTable(tableDir)
    % Finesse/linewidth vs. mirror power reflectivity, FSR held fixed at
    % 1 GHz (matched mirrors, so R = InputMirrorPowerReflectivity =
    % BackMirrorPowerReflectivity).
    powerReflectivities = [0.9, 0.99, 0.999, 0.9999];
    fid = fopen(fullfile(tableDir, "finesse-vs-reflectivity.tex"), "w");
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, "\\begin{tabular}{@{}llll@{}}\n\\toprule\n");
    fprintf(fid, "$R = R_1 = R_2$ & Finesse & Linewidth (FWHM) & $\\pi/(1-R)$ \\\\\n\\midrule\n");
    for R = powerReflectivities
        cavity = OpticalCavity(0.149896229, 1064e-9, R, R);
        fprintf(fid, "%.4f & %.1f & \\SI{%.4g}{\\hertz} & %.1f \\\\\n", ...
            R, cavity.Finesse, cavity.LinewidthFWHM, pi/(1-R));
    end
    fprintf(fid, "\\bottomrule\n\\end{tabular}\n");
end
