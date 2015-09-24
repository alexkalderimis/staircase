(ns staircase.views.footer
    (:require [staircase.views.header :refer (tool-list)]
              [hiccup.element :refer (link-to unordered-list mail-to)]))

(defn snippet [config]
  [:section.footer.dark.container-fluid {:ng-controller "FooterCtrl"}
   [:div.row
    [:div.col-sm-8.site-map
     [:ul
      [:li (link-to "/" "Home")]
      [:li (link-to "/about" "Help")]
      [:li [:a
            {:ng-click "showTools = !showTools"}
            "Tools "
            [:i.fa
             {:ng-class "{'fa-caret-right': !showTools, 'fa-caret-down': showTools}"}]]
           [:ul.row
            {:ng-class "{hidden: !showTools}"}
            (tool-list {:class "col-sm-4 col-md-3"})]]]]
    [:div.col-sm-4.contacts
     (unordered-list (for [[icon addr text] (:contacts config)]
                       (link-to {:title text} addr [:i.fa.fa-fw.fa-2x {:class icon}])))]
    ]
   [:div#cookie-message.row.panel.panel-info {:ng-show "showCookieMessage"}
    [:div.panel-heading "Cookies"]
      [:div.panel-body.flex-row.guttered
        [:div.flex-box.fit
          [:p
            "This site uses cookies to provide essential functionality, such as remembering your
            identity. You can find out details of what information we store here "
            (link-to "/cookies" "here")
            ". By dismissing this message you agree to let this application store the data it needs
            to operate."]]
        [:div.flex-box
          [:button.btn.btn-warning.pull-right {:ng-click "showCookieMessage = false"} "understood"]]
      ]]
   ])
