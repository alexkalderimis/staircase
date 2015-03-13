(ns staircase.resources.steps
  (:use staircase.protocols
        staircase.helpers
        [clojure.tools.logging :only (info)])
  (:import java.sql.SQLException)
  (:require staircase.sql
            clojure.string
            [cheshire.core :as json]
            [staircase.resources.schema :as schema]
            [com.stuartsierra.component :as component]
            [clojure.java.jdbc :as sql]))

(def table-specs (merge schema/history-step schema/steps schema/projects schema/project-contents))

(defn- get-first [m ks]
  (get m (first (filter (set (keys m)) ks))))

(defn- get-prop [m k] (get-first m [k (name k)]))

;; Make sure the thing we have is a string.
(defn ensure-string [maybe-string]
  (if (instance? String maybe-string)
    maybe-string
    (json/generate-string maybe-string)))

;; Transformations can be put in here on the stored step data.
;; At the moment we just make sure we parse the data from JSON.
(defn parse-data [step] 
  (when step
    (update-in step [:data] json/parse-string)))

(def parse-steps (comp vec (partial map parse-data)))

(defrecord StepsResource [db]
  component/Lifecycle 

  (start [component]
    (let [conn (:connection db)]
      (staircase.sql/create-tables conn table-specs))
    component)

  (stop [component] component)

  Resource
  
  (get-all [_] (sql/query (:connection db)
                          ["select * from steps"]
                          :result-set-fn parse-steps))

  (exists? [_ id] (staircase.sql/exists (:connection db) :steps id))

  (get-one [_ id]
    (when-let [uuid (string->uuid id)]
      (sql/query
        (:connection db)
        ["select * from steps where id = ?" uuid]
        :result-set-fn (comp parse-data first))))

  (update [_ id doc] (staircase.sql/update-entity (:connection db) :steps id doc))

  (delete [_ id]
    (when-let [uuid (string->uuid id)]
      (sql/with-db-transaction [conn (:connection db)]
        (sql/delete! conn :steps ["id=?" uuid])
        (sql/delete! conn :history_step ["step_id=?" uuid])))
    nil)

  (create [_ doc] ;; TODO: reuse existing steps where possible...
    (let [id (new-id)
          step (-> doc
                   (dissoc "history_id" :history_id :id) 
                   (assoc "id" id)
                   (update-in ["data"] ensure-string))
          link {"history_id" (java.util.UUID/fromString (str (get-prop doc :history_id))) ;; Make sure the id is a uuid
                "step_id" id
                "created_at" (sql-now)}]
      (sql/with-db-transaction [trs (:connection db)]
        (sql/insert! trs :steps step)
        (sql/insert! trs :history_step link))
      id)))

(defn new-steps-resource [& {:keys [db]}] (map->StepsResource {:db db}))
