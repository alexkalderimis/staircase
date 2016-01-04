(ns staircase.views.history
  (:require staircase.views.forms
            [hiccup.def :refer (defelem)]
            [staircase.views.buttons :as btn])
  (:use [hiccup.core :only (html)]
        [hiccup.element :only (mail-to)]))

(defelem tool-not-found [{contact :contact-email}]
  [:div.alert.alert-danger
   [:h3 "Error"]
   [:p
    " The required tool for this step could not be found. Check with the site
    administrator to make sure that the "
    [:code "{{step.tool}}"]
    " tool is installed"]
   (update-in (mail-to contact
                       [:span
                        [:i.fa.fa-envelope-o]
                        " Send a grumpy email"])
              [1 :class] (constantly "btn btn-default"))])

(def current-history
  [:div.current-history.panel.panel-default
   (apply vector
          :div.panel-heading
          (btn/collapse-button)
          (btn/edit-button)
          (btn/cancel-button {:ng-click "appView()"})
          (btn/save-button {:ng-click "appView()"})
          (staircase.views.forms/label-input-pair "history.title"))
   (apply vector
          :div.panel-body
          [:p [:small [:em "{{history.created_at | roughDate }}"]]]
          (staircase.views.forms/label-input-pair "history.description"))
   [:div.flex-row.stretched
    {:ng-if "steps.length > 4"}
    [:a.toggle-elisions {:ng-click "appView.elide = !appView.elide"}
     [:small "show all steps"]]]
    [:div.list-group.history-steps
     [:a.list-group-item {:ng-repeat "s in steps"
                          :ng-controller "HistoryStepCtrl as stepCtrl"
                          :ng-class "{active: step.id == s.id}"
                          :href "/history/{{history.id}}/{{$index + 1}}"
                          :folded "elide"}
      [:i.pull-right.fa.fa-edit
       {:ng-click "openEditDialogue()"
        :ng-show "step.id == s.id"}]
      "{{s.title}}"]]])

(defn left-column [config]
 [:div.blind.left
  {:ng-class "{open: openhistory}"
  :ng-mouseleave "shrinkhistory()"
  :ng-mouseenter "expandhistory()"
  :scrollable ""}
  [:div.contents-container
   [:div.steps
    [:a
      [:div.step
       [:div.summary.highlighted
        [:div.step-header "Previous Steps"]]]]
    [:a {:ng-href "/history/{{history.id}}/{{steps.length - $index}}"
        :ng-repeat "s in steps | reverse"
         :ng-controller "HistoryStepCtrl as stepCtrl"}
    [:div.step
      {:ng-class "{hot: step.id == s.id}"}
     [:div.summary
      [:span.badge.numbering "{{steps.indexOf(s) + 1}}"]
      [:i.fa.fa-clock-o.fa-2x]
      [:div "{{s.title}}"]]
     [:div.details {:ng-class "{transparent: !openhistory}"} "{{s.description}}"]]]]]])

 (defn right-column [config]

  [:div

  [:div.dropdown.currentdata {:dropdown true}
   [:div.dropdown-toggle.currentdata-toggle
     {:ng-if "idlists.length > 0" :ng-attr-dropdown-toggle true} [:span "{{datainfo}}" [:b.caret]]]
   [:div.dropdown-toggle.currentdata-toggle
     {:ng-if "idlists.length < 1"} [:span "{{datainfo}}"]]
    [:ul.dropdown-menu.dropdown-menu-right
    [:li
     {:ng-repeat "idlist in idlists"
      :ng-show "ccat.label == null"
      :ng-click "makeactive(idlist)"}
     [:h4 "{{idlist.ids.length}} {{idlist.type}}s"]
     "{{idlist.label}}"]]]

  [:div.blind.right

   {:ng-class "{open: opennextsteps}"
   :ng-mouseleave "shrinknextsteps(); clearcc()"
   :scrollable ""}

   [:div.contents-container
    [:div.steps.right {:ng-mouseenter "expandnextsteps()"}
    [:div.details.right
        [:next-step
         {:ng-repeat "ns in nextSteps"
          :previous-step "step"
          :append-step "appView.nextStep(data)"
          :tool "ns.tool"
          :category "ns.category"
          :service "ns.service"
          :ng-show "ns.category.label==ccat.label"
          :data "ns.data"}]

        [:div
         {:ng-repeat "idlist in idlists"
          :ng-show "ccat.label == null"
          :ng-click "makeactive(idlist)"}
         [:h4 "{{idlist.ids.length}} {{idlist.type}}s"]
         "{{idlist.label}}"]]

     [:a {:ng-href "#"
         :ng-repeat "category in categories"
         :ng-mouseenter "showtools(category)"}
     [:div.step.empty {:ng-class "{hot: step.id == s.id}"}
      [:div.summary {:ng-class "{highlighted: category.label == ccat.label}"}
       [:i.fa-2x {:class "{{category.icon}}"}]
       [:div "{{category.label}}"]]]]]]]])



(defn centre-column [config]
  [:div.central-panel
   (tool-not-found {:ng-show "error.status === 404"} config)
   [:div.current-step
    {:ng-hide "error.status === 404"
     :tool "tool"
     :step "step"
     :state "state"
     :has-items "appView.setItems(key, type, ids)"
     :has "appView.hasSomething(what, data, key)"
     :wants "appView.wantsSomething(what, data)"
     :next-step "appView.nextStep(data)"
     :silently "appView.storeHistory(data)"
     :toggle "state.expanded = !state.expanded"} ]])

(defn snippet [config]
  (html [:div.container-fluid.history-view
         (apply vector :div.row.flex-row
          ((juxt left-column centre-column right-column) config))]))
