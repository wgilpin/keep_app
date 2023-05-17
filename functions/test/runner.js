const index = require("../index.js");

index.doTextSearch(
    "hello",
    10,
    "zdt3YB86kJaxsESbMmkblkqQ3093")
    .then((res) => {
      console.log(res);
    });

index.doNoteSearch(
    "EoHdKsphl72uXwMv5akT",
    10,
    "zdt3YB86kJaxsESbMmkblkqQ3093")
    .then((res) => {
      console.log(res);
    });

