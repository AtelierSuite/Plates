// Safari runs this before the share sheet opens, and RecipeWebPage runs the same file in its
// hidden page. Safari passes run an object holding completionFunction, not the function itself.
var ExtensionPreprocessingJS = {
  run: function (parameters) {
    parameters.completionFunction(ExtensionPreprocessingJS.read());
  },

  finalize: function () {},

  read: function () {
    var scripts = [];
    try {
      scripts = Array.prototype.slice.call(
        document.querySelectorAll('script[type^="application/ld+json"]'), 0, 10
      ).map(function (script) { return script.textContent.slice(0, 100000); });
    } catch (error) {}
    try {
      var microdata = ExtensionPreprocessingJS.microdataRecipe();
      if (microdata) { scripts.push(microdata); }
    } catch (error) {}
    return { url: document.URL, jsonLD: scripts };
  },

  // Some pages, Squarespace's among them, mark their recipe up in microdata and write no
  // JSON-LD, so the microdata is written out as JSON-LD for the app to read the same way.
  microdataRecipe: function () {
    var root = document.querySelector('[itemscope][itemtype*="schema.org/Recipe"]');
    if (!root) { return null; }
    var owned = function (name) {
      return Array.prototype.slice.call(root.querySelectorAll('[itemprop~="' + name + '"]'))
        .filter(function (element) {
          return element.parentElement.closest('[itemscope]') === root;
        });
    };
    var value = function (element) {
      var text = element.getAttribute('content') || element.getAttribute('datetime');
      if (text) { return text.trim(); }
      var nested = element.hasAttribute('itemscope') && element.querySelector('[itemprop~="text"]');
      return ((nested || element).innerText || element.textContent || '').trim();
    };
    var values = function (name) {
      return owned(name).map(value).filter(function (text) { return text.length > 0; });
    };
    var instructions = [];
    owned('recipeInstructions').forEach(function (element) {
      var items = element.hasAttribute('itemscope') ? [] : element.querySelectorAll('li');
      if (items.length > 0) {
        Array.prototype.forEach.call(items, function (item) { instructions.push(value(item)); });
      } else {
        value(element).split(/\n+/).forEach(function (line) { instructions.push(line); });
      }
    });
    var first = function (name) { return values(name)[0] || ''; };
    return JSON.stringify({
      '@type': 'Recipe',
      name: first('name'),
      recipeIngredient: values('recipeIngredient').concat(values('ingredients')),
      recipeInstructions: instructions
        .map(function (line) { return line.trim(); })
        .filter(function (line) { return line.length > 0; }),
      totalTime: first('totalTime'),
      prepTime: first('prepTime'),
      cookTime: first('cookTime'),
      recipeYield: first('recipeYield')
    });
  }
};
