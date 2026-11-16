.pragma library

// The duck's colours: eight standard Call duck varieties, drakes. White is the locked design exactly.
// Each palette colours the rig (DuckRig.qml, written by duck/rig2qml.py):
//   body / head / tail   4 stops of the plumage's radial shading (light centre to shaded edge)
//   wing / primaries / farWing (2 stops), wingOpen (3 stops), bill (2 stops: top, base), jaw, billEdge (its outline)
//   farEdge (the far wing's edge over the back)
//   pattern shapes, "transparent" when a variety has none: cap, back (saddle), breast, bib, ring (neck ring),
//   speculum (the band on the folded wing)
//   sheen: how strongly the white light on the head and breast shows (1 on white plumage, less on dark)
// `swatch` is the colour the editor shows for it.

var none = "transparent";

var white = {
    body: ["#ffffff", "#f6f4ee", "#e2e3e4", "#c6c9d0"],
    head: ["#ffffff", "#f6f4ee", "#e2e3e4", "#c6c9d0"],
    tail: ["#ffffff", "#f6f4ee", "#e2e3e4", "#c6c9d0"],
    wing: ["#fdfcf9", "#dfe2e7"], primaries: ["#cdd2da", "#f3f2ee"], farWing: ["#d3d7de", "#e9ebee"],
    wingOpen: ["#e9ebef", "#fbfaf7", "#eceef1"], farEdge: "#e6e8ec",
    bill: ["#ffc35e", "#ec8f2c"], jaw: "#d97a22", billEdge: "#c46c22",
    cap: none, back: none, breast: none, bib: none, ring: none, speculum: none, sheen: 1,
    // the fine detail drawn for white plumage: outline, feather lines (l_ + the original grey), eye ring, the chin's
    // shade, the feathers at the bill's base, and the grey shading under the belly and on the far rear
    outline: "#aeb3bb", eyeRing: "#ece8df", chin: "#c4c9d1", billBase: "#d9dce1", shade: 1,
    l_b8bdc5: "#b8bdc5", l_bfc4cc: "#bfc4cc", l_c3c7ce: "#c3c7ce", l_c3c8cf: "#c3c8cf", l_c6cad1: "#c6cad1",
    l_c9cdd4: "#c9cdd4", l_cdd1d7: "#cdd1d7", l_cfd3d9: "#cfd3d9"
};

// dark plumage: the fine detail turns dark too (one colour for every feather line)
function darkDetail(line, outline, eyeRing) {
    return { outline: outline, eyeRing: eyeRing, chin: line, billBase: line, shade: 0.2,
             l_b8bdc5: line, l_bfc4cc: line, l_c3c7ce: line, l_c3c8cf: line, l_c6cad1: line, l_c9cdd4: line, l_cdd1d7: line, l_cfd3d9: line };
}

function variety(o, detail) {
    const v = {};
    for (const k in white) v[k] = white[k];
    for (const k in (detail || {})) v[k] = detail[k];
    for (const k in o) v[k] = o[k];
    return v;
}

var list = [
    { id: "white", name: "White", swatch: "#f6f4ee", p: white },
    { id: "mallard", name: "Mallard", swatch: "#2f7d4f", p: variety({
        head: ["#3f9a68", "#24774b", "#185636", "#0f3a25"],
        body: ["#d2d0c9", "#bab7ae", "#a19e95", "#86837b"],
        tail: ["#4a4946", "#33322f", "#252422", "#191817"],
        wing: ["#aaa395", "#878071"], primaries: ["#8c8578", "#b2aa9c"], farWing: ["#8a8376", "#a39b8d"],
        wingOpen: ["#958e80", "#b6ae9f", "#a29a8c"], farEdge: "#9b9486",
        bill: ["#dcd36e", "#b8ad48"], jaw: "#a89c3e", billEdge: "#9a903d",
        back: "#7c766b", breast: "#7d3c25", ring: "#f6f4ee", speculum: "#2d51a8", sheen: 0.35 }) },
    { id: "blueMallard", name: "Blue Mallard", swatch: "#3f6f7c", p: variety({
        head: ["#4a8590", "#336a75", "#244f58", "#17363d"],
        body: ["#c3c9d1", "#aab1ba", "#9098a2", "#767e88"],
        tail: ["#4d535b", "#373c43", "#282c32", "#1b1e22"],
        wing: ["#9aa2ac", "#7a828c"], primaries: ["#7f8790", "#a6aeb7"], farWing: ["#808891", "#9aa2ab"],
        wingOpen: ["#8b939d", "#aab2bc", "#98a0aa"], farEdge: "#8e96a0",
        bill: ["#d6cf72", "#b3a94c"], jaw: "#a29844", billEdge: "#958c40",
        back: "#68707a", breast: "#6e4747", ring: "#f6f4ee", speculum: "#3d5ea6", sheen: 0.35 }) },
    { id: "silver", name: "Silver", swatch: "#d9d6cf", p: variety({
        head: ["#4aa070", "#2f8156", "#21643f", "#164730"],
        body: ["#f5f3ee", "#e9e6df", "#d6d3cb", "#bfbcb4"],
        tail: ["#6d6b66", "#57554f", "#46443f", "#34332f"],
        wing: ["#ece8e0", "#d0cbc1"], primaries: ["#c5c0b6", "#e6e2da"], farWing: ["#cbc6bc", "#e1ddd5"],
        wingOpen: ["#d8d3c9", "#efebe4", "#dcd8cf"], farEdge: "#d9d5cc",
        bill: ["#dcd36e", "#b8ad48"], jaw: "#a89c3e", billEdge: "#9a903d",
        back: "#b2ada3", breast: "#9c5d47", ring: "#ffffff", speculum: "#4064b4", sheen: 0.6 }) },
    { id: "apricot", name: "Apricot Mallard", swatch: "#d6b48f", p: variety({
        head: ["#9aa889", "#808f72", "#68765c", "#525d48"],
        body: ["#ecdcc8", "#dcc6ad", "#c7ae93", "#ad937a"],
        tail: ["#8f7e6c", "#776756", "#615345", "#4b4036"],
        wing: ["#d8c4ab", "#b7a18a"], primaries: ["#ad9884", "#cfbca6"], farWing: ["#b29e88", "#cab6a0"],
        wingOpen: ["#c4af97", "#dfccb5", "#ccb9a2"], farEdge: "#c3ae96",
        bill: ["#dcd172", "#bbaf51"], jaw: "#a99f49", billEdge: "#9b9145",
        back: "#a58f77", breast: "#bf7d5b", ring: "#f4efe5", speculum: "#8296bb", sheen: 0.5 }) },
    { id: "butterscotch", name: "Butterscotch", swatch: "#e2bf8c", p: variety({
        head: ["#a9b08f", "#8f977a", "#767e64", "#5e654f"],
        body: ["#faf0e2", "#f1e2cd", "#e3cfb4", "#cdb699"],
        tail: ["#c2ad93", "#a99379", "#8f7b63", "#75644f"],
        wing: ["#f3e7d6", "#dbc8ae"], primaries: ["#d2bea4", "#ecdcc6"], farWing: ["#d6c3a9", "#e8d8c2"],
        wingOpen: ["#e1cfb6", "#f5ebdc", "#e4d4bd"], farEdge: "#e0cdb3",
        bill: ["#e4d878", "#c4b657"], jaw: "#b0a34c", billEdge: "#a49849",
        back: "#d6bf9f", breast: "#d49c6c", ring: "#ffffff", speculum: "#9cabc6", sheen: 0.7 }) },
    { id: "magpie", name: "Magpie", swatch: "#222224", p: variety({
        tail: ["#3a3a3d", "#29292b", "#1e1e20", "#141416"],
        wing: ["#333336", "#1f1f21"], primaries: ["#1c1c1e", "#38383b"], farWing: ["#232325", "#333336"],
        wingOpen: ["#2a2a2d", "#3a3a3d", "#2e2e31"], farEdge: "#2a2a2d",
        bill: ["#f6c866", "#e39b3c"], jaw: "#cf8a33", billEdge: "#c27f2e",
        cap: "#1f1f21", back: "#1f1f21", sheen: 1 }) },
    { id: "bibbed", name: "Bibbed", swatch: "#2a2f2c", p: variety({
        head: ["#3d4d44", "#2a372f", "#1d2621", "#131a16"],
        body: ["#4a4a4d", "#363638", "#28282a", "#1b1b1d"],
        tail: ["#3a3a3c", "#2a2a2c", "#1e1e20", "#141416"],
        wing: ["#3c3c3f", "#262628"], primaries: ["#232325", "#3d3d40"], farWing: ["#2a2a2c", "#3a3a3d"],
        wingOpen: ["#303033", "#444447", "#353538"], farEdge: "#323235",
        bill: ["#4a4f48", "#2e322d"], jaw: "#262a25", billEdge: "#1e221d",
        bib: "#f4f2ec", speculum: "#2f4f72", sheen: 0.12 }, darkDetail("#55595a", "#0f1011", "#3a3d3b")) }
];

function palette(id) {
    for (const v of list) if (v.id === id) return v.p;
    return white;
}
