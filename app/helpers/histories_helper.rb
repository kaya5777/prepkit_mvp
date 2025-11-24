module HistoriesHelper
  # 現在のユーザーが履歴の所有者かどうか
  def can_edit_history?(history)
    history.user == current_user
  end

  # ユーザーの表示名を取得
  def user_display_name(user)
    user.name || user.email.split('@').first
  end

  # ユーザーのアバター初期を取得
  def user_avatar_initial(user)
    user.name&.first&.upcase || user.email&.first&.upcase
  end

  # ユーザーのアバターを表示
  def user_avatar(user, size: 'w-6 h-6', text_size: 'text-xs')
    if user.avatar_url.present?
      image_tag user.avatar_url, alt: user_display_name(user), class: "#{size} rounded-full object-cover"
    else
      content_tag(:div, class: "#{size} bg-primary-100 rounded-full flex items-center justify-center") do
        content_tag(:span, user_avatar_initial(user), class: "text-primary-600 font-semibold #{text_size}")
      end
    end
  end

  # ユーザーのアバターと名前を一緒に表示
  def user_avatar_with_name(user, avatar_size: 'w-6 h-6', text_size: 'text-xs', name_class: 'text-sm text-secondary-600')
    content_tag(:div, class: "flex items-center gap-2") do
      concat(user_avatar(user, size: avatar_size, text_size: text_size))
      concat(content_tag(:span, user_display_name(user), class: name_class))
    end
  end

  # SVGアイコンを生成
  def icon_svg(path, css_class: "w-5 h-5")
    content_tag(:svg, class: css_class, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: path)
    end
  end

  # チェックマークアイコン
  def check_icon(css_class: "w-5 h-5")
    icon_svg("M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z", css_class: css_class)
  end

  # 質問アイコン
  def question_icon(css_class: "w-5 h-5")
    icon_svg("M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z", css_class: css_class)
  end

  # スターアイコン
  def star_icon(css_class: "w-5 h-5")
    icon_svg("M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z", css_class: css_class)
  end

  # 編集アイコン
  def edit_icon(css_class: "w-5 h-5")
    icon_svg("M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z", css_class: css_class)
  end

  # 削除アイコン
  def delete_icon(css_class: "w-5 h-5")
    icon_svg("M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16", css_class: css_class)
  end

  # 警告アイコン
  def warning_icon(css_class: "w-5 h-5")
    icon_svg("M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z", css_class: css_class)
  end

  # 矢印アイコン（塗りつぶし）
  def arrow_icon_filled(css_class: "w-5 h-5")
    content_tag(:svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20") do
      content_tag(:path, nil, "fill-rule": "evenodd", d: "M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z", "clip-rule": "evenodd")
    end
  end

  # セクションヘッダーを生成
  def section_header(title, gradient_classes, icon: nil)
    content_tag(:div, class: "#{gradient_classes} px-6 py-4 border-b border-gray-200") do
      content_tag(:div, class: "flex items-center gap-2") do
        concat(icon) if icon
        concat(content_tag(:h2, title, class: "text-xl font-bold text-gray-900"))
      end
    end
  end

  # バッジ付き番号を生成
  def numbered_badge(number, color_class: "bg-indigo-600")
    content_tag(:span, number, class: "flex-shrink-0 w-8 h-8 #{color_class} text-white rounded-full flex items-center justify-center font-semibold text-sm")
  end

  # STAR回答のラベルを生成
  def star_label(letter, color_class)
    content_tag(:span, "#{letter}:", class: "font-bold #{color_class} w-20 flex-shrink-0")
  end
end
