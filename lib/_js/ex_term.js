(() => {
    const terminal = document.getElementById("exterm-terminal");
    const paste_target = document.getElementById("exterm-paste-target")

    terminal.addEventListener("exterm:mounted", event => {
        const console = document.getElementById("exterm-console");
        console.addEventListener("keydown", event => {
            // prevents the default event from firing (this is keystrokes hitting the
            // edited content of the div)
            console.log("hi mom");
            event.preventDefault();
        })
        setTimeout(() => event.target.scroll(0, 30), 100);
    })

    terminal.addEventListener("keydown", event => {
        // prevents the default event from firing (this is mostly tab focusing,
        // but also contenteditable changes)
        event.preventDefault();
    })

    const rowCol = (node) => {
        var id;
        if (node.nodeType === 3) { id = node.parentNode.id } else { id = node.id }
        [_, _, row, col] = id.split("-");
        return [Number(row), Number(col)];
    }

    const fetchCols = (row, [row1, col1], [row2, col2]) => {
        var col_start = 0;
        var line = "";
        var index = 1;
        var buffered_spaces = 0;
        if (row == row1) { index = col1; }

        while (true) {
            element = document.getElementById("exterm-cell-" + row + "-" + index);
            // pull out if we're at the end of the line.
            if (!element) break;

            // if it's empty then don't add it in, just increment buffered spaces
            var content = element.textContent.trim();

            if (content === "") {
                buffered_spaces += 1;
            } else {
                line += " ".repeat(buffered_spaces) + content;
                buffered_spaces = 0;
            }

            // pull out if we're at the end.
            if (row == row2 && index == col2) break;
            index += 1;
        }
        return line + "\n"
    }

    const fetchRows = (coord1, coord2) => {
        // first put rows in order.
        var start, end;
        if (coord1[0] < coord2[0]) {
            start = coord1;
            end = coord2;
        } else if (coord1[0] == coord2[0]) {
            if (coord1[1] < coord2[1]) {
                start = coord1;
                end = coord2;
            } else {
                start = coord2;
                end = coord1;
            }
        } else {
            start = coord2;
            end = coord1;
        }
        var result = "";
        for (let index = start[0]; index <= end[0]; index++) {
            result += fetchCols(index, start, end);
        }
        return result;
    }

    const modifyClipboard = (event) => {
        const selection = window.getSelection();
        copied = fetchRows(rowCol(selection.anchorNode), rowCol(selection.focusNode));
        event.clipboardData.setData("text/plain", copied);
        event.preventDefault();
    }

    const sendPaste = (event) => {
        const paste_data = event.clipboardData.getData("text/plain");
        paste_target.setAttribute("phx-value-paste", paste_data);
        paste_target.click();
        event.preventDefault();
    }

    terminal.addEventListener("copy", modifyClipboard);
    terminal.addEventListener("paste", sendPaste)
})()