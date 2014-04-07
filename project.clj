(defproject staircase "0.1.0-SNAPSHOT"
  :description "The application holding data-flow steps."
  :url "http://steps.intermine.org"
  :dependencies [[org.clojure/clojure "1.5.1"]
                 [compojure "1.1.6"] ;; Request handlers
                 [ring/ring-json "0.1.2"] ;; JSON marshalling
                 [c3p0/c3p0 "0.9.1.2"] ;; DB pooling
                 [com.stuartsierra/component "0.2.1"] ;; Dependency management
                 [org.clojure/java.jdbc "0.2.3"] ;; DB interface
                 [com.h2database/h2 "1.3.168"]   ;; DB Driver
                 [cheshire "4.0.3"]] ;; JSON serialisation
  :plugins [[lein-ring "0.8.10"]]
  :ring {:handler staircase.handler/app}
  :profiles
  {:dev {:dependencies [[javax.servlet/servlet-api "2.5"]
                        [ring-mock "0.1.5"]]}})
