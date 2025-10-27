module PreparationsHelper
  # 情報アイコン
  def info_icon(css_class: "w-5 h-5")
    content_tag(:svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20") do
      content_tag(:path, nil, "fill-rule": "evenodd", d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z", "clip-rule": "evenodd")
    end
  end

  # プラスアイコン
  def plus_icon(css_class: "w-5 h-5")
    content_tag(:svg, class: css_class, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M12 6v6m0 0v6m0-6h6m-6 0H6")
    end
  end

  # メッセージアイコン
  def message_icon(css_class: "w-6 h-6")
    content_tag(:svg, class: css_class, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z")
    end
  end

  # クリップボードアイコン
  def clipboard_icon(css_class: "w-6 h-6")
    content_tag(:svg, class: css_class, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4")
    end
  end
end
