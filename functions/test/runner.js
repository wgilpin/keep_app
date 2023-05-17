const index = require("../index.js");

index.doTextSearch(
    "Note Four",
    10,
    "zdt3YB86kJaxsESbMmkblkqQ3093")
    .then((res) => {
      console.log(res);
    });

index.doNoteSearch(
    "FgtHXS1200uAsLUyTjHx",
    10,
    "zdt3YB86kJaxsESbMmkblkqQ3093")
    .then((res) => {
      console.log(res);
    });
