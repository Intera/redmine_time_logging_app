/* jquery.contenttitle.src.js 2012-11-6 | https://github.com/jkalbhenn/jquery.contenttitle */
;(function () {
	function getTitleFunc (ele, config) {
		if (config["title_attribute"]) {
			var titleAttribute = config["title_attribute"]
			return function () { return ele.attr(titleAttribute) }
		}
		else if (config["title"]) {
			var title = config["title"]
			return function () { return title }
		}
		else if (config["title_selector"]) {
			var titleSelector = config["title_selector"]
			return function () { return jQuery(titleSelector).html() }
		}
		else {
			return function () { return "" }
		}
	}

	var defaultConfig = {
		// set title from html attribute
		title_attribute: "title",
		// set title
		title: false,
		// set title from html element content
		title_selector: false,
		title_class: "contentTitle"
	}

	/* activate the contentTitle functionality for a single element */
	function contentTitleOne (ele, config) {
		var getTitle = getTitleFunc(ele, config)
		var titleClass = config["title_class"]
		if (ele.is("select")) {
			var titleOption = jQuery('<option>').attr({selected: true, value: ""}).html(getTitle()).addClass(titleClass)
			ele.prepend(titleOption)
			ele.change(
				function () {
					if (ele.children(":selected").html() == getTitle()) { ele.addClass(titleClass)	}
					else { ele.removeClass(titleClass) }
				}
			).change()
		}
		else {
			function onFocus () {
				// empty on click if value is default value
				if (ele.val() == getTitle()) { ele.removeClass(titleClass).val("")	}
			}
			function onBlur () {
				// reset to title if empty
				if (ele.val().length == 0) { ele.addClass(titleClass).val(getTitle())	}
			}
			ele.focus(onFocus).blur(onBlur)
			onFocus(); onBlur()
		}
	}

	jQuery.fn.contentTitle = function (config) {
		if (!config) { config = defaultConfig }
		this.each(function (index, ele) { contentTitleOne(jQuery(ele), config) })
	}
})()
