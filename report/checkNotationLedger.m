function [ok, violations] = checkNotationLedger(reportPath)
%CHECKNOTATIONLEDGER Verify report.tex's per-section glossary-table notation.
%   For every table labeled tab:*-glossary, checks (1) no symbol is defined
%   in more than one glossary table, and (2) no symbol is used in a math
%   region above its own table's line, unless that table's own "Meaning"
%   cell already carries a "[forward-reference: ...]" tag. See the
%   "Notation Ledger" entry in ../CONTEXT.md for the full convention,
%   including this checker's documented scope limits.

    arguments
        reportPath (1,1) string {mustBeFile}
    end

    text = fileread(reportPath);
    lineStarts = [1, strfind(text, newline) + 1];

    tables = findGlossaryTables(text, lineStarts);
    entries = extractSymbolEntries(text, tables);
    mathRegions = findMathRegions(text);

    violations = struct('kind', {}, 'symbol', {}, 'detail', {});
    violations = [violations, findDuplicateDefinitions(entries)];
    violations = [violations, findUndocumentedForwardReferences(entries, tables, mathRegions, text, lineStarts)];

    ok = isempty(violations);
end

function tables = findGlossaryTables(text, lineStarts)
    tables = struct('label', {}, 'tableStartLine', {}, 'tabularStartOffset', {}, 'tabularEndOffset', {});

    [labelStarts, labelTokens] = regexp(text, '\\label\{(tab:[\w-]*-glossary)\}', 'start', 'tokens');

    for k = 1:numel(labelStarts)
        labelOffset = labelStarts(k);
        label = string(labelTokens{k}{1});

        tableBeginOffset = lastIndexOf(text, '\begin{table}', labelOffset);
        tabularEndOffset = lastIndexOf(text, '\end{tabular}', labelOffset);
        tabularBeginOffset = lastIndexOf(text, '\begin{tabular}', tabularEndOffset);

        tables(end+1) = struct( ...
            'label', label, ...
            'tableStartLine', offsetToLine(tableBeginOffset, lineStarts), ...
            'tabularStartOffset', tabularBeginOffset, ...
            'tabularEndOffset', tabularEndOffset); %#ok<AGROW>
    end
end

function offset = lastIndexOf(text, pattern, beforeOffset)
    hits = strfind(text(1:beforeOffset), pattern);
    offset = hits(end);
end

function lineNum = offsetToLine(offset, lineStarts)
    lineNum = find(lineStarts <= offset, 1, 'last');
end

function entries = extractSymbolEntries(text, tables)
    entries = struct('symbol', {}, 'tableLabel', {}, 'tableLine', {}, 'meaning', {});

    for t = 1:numel(tables)
        tbl = tables(t);
        rowsText = text(tbl.tabularStartOffset:tbl.tabularEndOffset);
        rowLines = strsplit(rowsText, newline);

        headerSeen = false;
        for r = 1:numel(rowLines)
            row = strtrim(rowLines{r});
            if row == "" || startsWith(row, "\begin{tabular}") || startsWith(row, "\end{tabular}") ...
                    || startsWith(row, "\toprule") || startsWith(row, "\midrule") || startsWith(row, "\bottomrule")
                continue
            end
            if ~headerSeen
                headerSeen = true;
                continue
            end

            cols = strsplit(erase(row, "\\"), "&");
            if numel(cols) < 3
                continue
            end
            meaning = strtrim(strjoin(cols(3:end), "&"));
            symbolSpans = regexp(cols{1}, '\$[^$]+\$', 'match');
            for s = 1:numel(symbolSpans)
                span = symbolSpans{s};
                entries(end+1) = struct( ...
                    'symbol', string(span(2:end-1)), ...
                    'tableLabel', tbl.label, ...
                    'tableLine', tbl.tableStartLine, ...
                    'meaning', string(meaning)); %#ok<AGROW>
            end
        end
    end
end

function regions = findMathRegions(text)
    regions = struct('startOffset', {}, 'endOffset', {});

    [inlineStarts, inlineEnds] = regexp(text, '\$[^$]+\$', 'start', 'end');
    for k = 1:numel(inlineStarts)
        regions(end+1) = struct('startOffset', inlineStarts(k), 'endOffset', inlineEnds(k)); %#ok<AGROW>
    end

    [eqStarts, eqEnds] = regexp(text, '\\begin\{equation\}[\s\S]*?\\end\{equation\}', 'start', 'end');
    for k = 1:numel(eqStarts)
        regions(end+1) = struct('startOffset', eqStarts(k), 'endOffset', eqEnds(k)); %#ok<AGROW>
    end

    if ~isempty(regions)
        [~, order] = sort([regions.startOffset]);
        regions = regions(order);
    end
end

function violations = findDuplicateDefinitions(entries)
    violations = struct('kind', {}, 'symbol', {}, 'detail', {});
    if isempty(entries)
        return
    end

    symbols = [entries.symbol];
    uniqueSymbols = unique(symbols);
    for u = 1:numel(uniqueSymbols)
        matchIdx = (symbols == uniqueSymbols(u));
        tableLabels = unique([entries(matchIdx).tableLabel]);
        if numel(tableLabels) > 1
            violations(end+1) = struct( ...
                'kind', "duplicate-definition", ...
                'symbol', uniqueSymbols(u), ...
                'detail', sprintf("defined in both %s", strjoin(tableLabels, " and "))); %#ok<AGROW>
        end
    end
end

function violations = findUndocumentedForwardReferences(entries, tables, mathRegions, text, lineStarts)
    violations = struct('kind', {}, 'symbol', {}, 'detail', {});
    forwardNoteMarker = "[forward-reference:";

    for e = 1:numel(entries)
        entry = entries(e);
        symbolPattern = "(?<![A-Za-z0-9])" + regexptranslate('escape', entry.symbol) + "(?![A-Za-z0-9])";

        firstUseOffset = NaN;
        for r = 1:numel(mathRegions)
            region = mathRegions(r);
            if isInsideAnyGlossaryTable(region, tables)
                continue
            end
            if ~isempty(regexp(text(region.startOffset:region.endOffset), symbolPattern, 'once'))
                firstUseOffset = region.startOffset;
                break
            end
        end

        if ~isnan(firstUseOffset)
            firstUseLine = offsetToLine(firstUseOffset, lineStarts);
            if firstUseLine < entry.tableLine && ~contains(entry.meaning, forwardNoteMarker)
                violations(end+1) = struct( ...
                    'kind', "undocumented-forward-reference", ...
                    'symbol', entry.symbol, ...
                    'detail', sprintf("used at line %d, before its table %s at line %d, with no forward-reference note", ...
                        firstUseLine, entry.tableLabel, entry.tableLine)); %#ok<AGROW>
            end
        end
    end
end

function tf = isInsideAnyGlossaryTable(region, tables)
    tf = false;
    for t = 1:numel(tables)
        if region.startOffset >= tables(t).tabularStartOffset && region.endOffset <= tables(t).tabularEndOffset
            tf = true;
            return
        end
    end
end
