(ns staircase.handler
  (:use compojure.core
        ring.util.response
        [ring.middleware.session :only (wrap-session)]
        [ring.middleware.cookies :only (wrap-cookies)]
        ring.middleware.json
        ring.middleware.format
        ring.middleware.anti-forgery
        [staircase.protocols] ;; Compile, so import will work.
        [staircase.helpers :only (new-id)]
        [clojure.tools.logging :only (debug info error)]
        [clojure.algo.monads :only (domonad maybe-m)])
  (:require [compojure.handler :as handler]
            [devlin.table-utils :refer (full-outer-join)]
            [clj-jwt.core  :as jwt]
            [clj-jwt.key   :refer [private-key public-key]]
            [clj-jwt.intdate :refer [intdate->joda-time]]
            [clj-time.core :as t]
            [cheshire.core :as json]
            [clj-http.client :as client]
            [com.stuartsierra.component :as component]
            [ring.middleware.cors :refer (wrap-cors)]
            staircase.resources
            [persona-kit.friend :as pf]
            [persona-kit.core :as pk]
            [persona-kit.middleware :as pm]
            [cemerick.friend :as friend] ;; auth.
            [cemerick.friend.workflows :as workflows]
            [staircase.tools :refer (get-tools get-tool)]
            [staircase.data :as data] ;; Data access routines that don't map nicely to resources.
            [staircase.views :as views] ;; HTML templating.
            [compojure.route :as route]
            [staircase.projects :as projects])
  )

;; TODO: this file is much too large, and in serious need of refactoring.

(def NOT_FOUND {:status 404})
(def ACCEPTED {:status 204})

(defn get-resource [rs id]
  (if-let [ret (.get-one rs id)]
    (response ret)
    NOT_FOUND))

;; Have to vectorise, since lazy seqs won't be jsonified.
(defn get-resources [rs] (response (into [] (.get-all rs))))

(defn create-new [rs doc]
  (let [id (.create rs doc)]
    (get-resource rs id)))

(defn update-resource [rs id doc]
  (if (.exists? rs id)
    (response (.update rs id doc))
    NOT_FOUND))

(defn delete-resource [rs id]
  (if (.exists? rs id)
    (do 
      (.delete rs id)
      ACCEPTED)
    NOT_FOUND))

(defn register-for ;; currently gets anon session. Needs api hf to be applied.
  [service]
  (let [session-url (str (:root service) "/session")
        resp (client/get session-url {:as :json :throw-exceptions false})]
    (get-in resp [:body :token])))

(defn get-end-of-history [histories id]
  (or
    (when-let [end (first (data/get-steps-of histories id :limit 1))]
      (response end))
    NOT_FOUND))

(defn get-steps-of [histories id]
  (or
    (when (.exists? histories id)
      (response (into [] (data/get-steps-of histories id))))
    NOT_FOUND))

(defn get-step-of [histories id idx]
  (or
    (domonad maybe-m ;; TODO: use offsetting rather than nth.
             [:when (.exists? histories id)
              i     (try (Integer/parseInt idx) (catch NumberFormatException e nil))
              step  (nth (data/get-steps-of histories id) i)]
          (response step))
    NOT_FOUND))

(defn fork-history-at [histories id idx body]
  (or
    (domonad maybe-m
             [original (get-one histories id)
              title (or (get body "title") (str "Fork of " (:title original)))
              history (assoc (dissoc original :id :steps) :title title)
              ;; Don't really have to nummify it - but is good to catch error here.
              limit (try (Integer/parseInt idx) (catch NumberFormatException e nil))
              inherited-steps (data/get-history-steps-of histories id limit)
              hid (create histories history)]
             (do
              (data/add-all-steps histories hid inherited-steps)
              (response (get-one histories hid))))
    NOT_FOUND))

(defn add-step-to [histories steps id doc]
  (if (exists? histories id)
    (let [to-insert (assoc doc "history_id" id)
          step-id (create steps to-insert)]
      (response (get-one steps step-id)))
    NOT_FOUND))

(defn- issue-session [config secrets ident]
  (let [key-phrase (:key-phrase secrets)
        claim (jwt/jwt {:iss (:audience config)
                        :exp (t/plus (t/now) (t/days 1))
                        :iat (t/now)
                        :prn ident})]
    (if-let [rsa-prv-key
             (try (private-key "rsa/private.key" key-phrase)
               (catch java.io.FileNotFoundException fnf nil))]
      (-> claim
          (jwt/sign :RS256 rsa-prv-key)
          jwt/to-str)
      (-> claim
          (jwt/sign :HS256 key-phrase)
          jwt/to-str))))

(defn get-principal [router auth]
  (or
    (when (and auth (.startsWith auth "Token: "))
      (let [token (.replace auth "Token: " "")
            web-token (jwt/str->jwt token)
            claims (:claims web-token)
            proof (try (public-key  "rsa/public.key")
                       (catch java.io.FileNotFoundException fnf
                         (get-in router [:secrets :key-phrase])))
            valid? (jwt/verify web-token proof)]
        (when (and valid? (t/after? (intdate->joda-time (:exp claims)) (t/now)))
          (:prn claims))))
    ::invalid))

(defn- wrap-api-auth [handler router]
  (fn [req]
    (let [auth (get-in req [:headers "authorization"])
          principal (get-principal router auth)]
      (if (= ::invalid principal)
        {:status 403 :body {:message "Bad authorization."}}
        (binding [staircase.resources/context {:user principal}]
          (handler (assoc req ::principal principal)))))))

;; Requires session functionality.
(defn app-auth-routes [{:keys [config secrets]}]
  (let [issue-session (partial issue-session config secrets)
        session-resp #(-> % issue-session response (content-type "application/json-web-token"))]
    (routes
      (GET "/csrf-token" [] (-> (response *anti-forgery-token*) (content-type "text/plain")))
      (GET "/session"
           {session :session :as r}
           (session-resp (:current (friend/identity r))))
      (POST "/login"
            {session :session :as r}
            (if (:email (friend/current-authentication r))
              (assoc (response (friend/identity r)) :session session) ;; Have to record session here.
              {:status 403}))
      (friend/logout (POST "/logout"
                           {session :session :as r}
                           (-> (response "ok")
                               (assoc :session (dissoc session :anon-identity))
                               (content-type "text/plain")))))))

;; replacement for persona-kit version. TODO: move to different file.
(defn persona-workflow [audience request]
  (if (and (= (:uri request) "/auth/login")
             (= (:request-method request) :post))
    (-> request
        :params
        (get "assertion")
        (pk/verify-assertion audience)
        pf/credential-fn
        (workflows/make-auth {::friend/redirect-on-auth? false
                              ::friend/workflow :mozilla-persona}))))

(defn anonymous-workflow [request]
  "Assign an identity if none is available."
  (if-not (:current (friend/identity request))
    (workflows/make-auth {:anon? true :identity (str (new-id))}
                         {::friend/redirect-on-auth? false
                          ::friend/workflow :anonymous})))

(defn credential-fn
  [auth]
  (case (::friend/workflow auth)
    :anonymous       (assoc auth :roles [])
    :mozilla-persona (assoc (pf/credential-fn auth) :roles [:user])))

(defn- read-token
  [req]
  (-> (apply merge (map req [:params :form-params :multipart-params]))
      :__anti-forgery-token))

(defn- build-app-routes [{conf :config :as router}]
  (let [serve-index (partial views/index conf)]
    (routes 
      (GET "/" [] (serve-index))
      (GET "/about" [] (serve-index))
      (GET "/projects" [] (serve-index))
      (GET "/history/:id/:idx" [] (serve-index))
      (GET "/starting-point/:tool" [] (serve-index))
      (GET "/starting-point/:tool/:service" [] (serve-index))
      (GET "/tools" [capabilities] (response (get-tools conf capabilities)))
      (GET "/tools/:id" [id] (if-let [tool (get-tool conf id)]
                              (response tool)
                              {:status 404}))
      (GET "/partials/:fragment.html"
          [fragment]
          (views/render-partial conf fragment))
      (context "/auth" [] (-> (app-auth-routes router)
                              (wrap-anti-forgery {:read-token read-token})))
      (route/resources "/" {:root "tools"})
      (route/resources "/" {:root "public"})
      (route/not-found (views/four-oh-four conf)))))

(defn- build-hist-routes [{:keys [histories steps]}]
  (routes ;; routes that start from histories.
          (GET  "/" [] (get-resources histories))
          (POST "/" {body :body} (create-new histories body))
          (context "/:id" [id]
                   (GET    "/" [] (get-resource histories id))
                   (PUT    "/" {body :body} (update-resource histories
                                                             id
                                                             (dissoc body "id" "steps" "owner")))
                   (DELETE "/" [] (delete-resource histories id))
                   (GET    "/head" [] (get-end-of-history histories id))
                   (context "/steps" []
                            (GET "/" [] (get-steps-of histories id))
                            (GET "/:idx" [idx] (get-step-of histories id idx))
                            (POST "/:idx/fork"
                                  {body :body {idx :idx} :params}
                                  (fork-history-at histories id idx body))
                            (POST "/" {body :body} (add-step-to histories steps id body))))))

(defn- build-project-routes [{:keys [projects]}]
  (routes ;; routes that start from histories.
          (GET  "/" [] (staircase.projects/get-all-projects))
          (POST "/" {payload :body} (staircase.projects/create-project payload))
          (context "/:id" [id]
            (GET  "/" [] (staircase.projects/get-single-project id))
            (DELETE  "/" [] (staircase.projects/delete-project id))
            (POST  "/" {payload :body} [] (staircase.projects/update-project id payload))
            (context "/items" [id]
              (POST "/" {payload :body}
                (staircase.projects/add-item-to-project id payload))
              (POST "/remove" {payload :body} [] (staircase.projects/delete-item payload))))))


(defn build-step-routes [{:keys [steps]}]
  (routes ;; routes for access to step data.
          (GET  "/" [] (get-resources steps))
          (context "/:id" [id]
                   (GET    "/" [] (get-resource steps id))
                   (DELETE "/" [] (delete-resource steps id)))))

(defn build-service-routes [{:keys [config services]}]
  (let [ensure-name (fn [service] (-> service (assoc :name (or (:name service) (:confname service))) (dissoc :confname)))
        ensure-token (fn [service] (if (:token service)
                                     service
                                     (let [token (register-for service)
                                           current (first (get-where services [:= :root (:root service)]))
                                           canon (if current
                                                  (update services (:id current) {:token token})
                                                  (get-one services (create services {:root (:root service) :token token})))]
                                       (merge service canon))))
        real-id #(if (= "default" %) (:default-service config) %)]
    (routes ;; Routes for getting service information.
            (GET "/" []
                 (locking services ;; Not very happy about this - is there some better way to avoid this bottle-neck?
                  (let [user-services (get-all services)
                        configured-services (->> config :services (map (fn [[k v]] {:root v :confname k})))]
                    (info "USER SERVICES" (count user-services) "CONF SERVICES" (count configured-services))
                    (response (vec (map (comp ensure-name ensure-token) (full-outer-join configured-services user-services :root)))))))
            (context "/:ident" [ident]
                     (GET "/" []
                          (locking services
                            (let [ident (real-id ident)
                                  uri (get-in config [:services ident])
                                  user-services (get-where services [:= :root uri])
                                  service (-> (full-outer-join [{:root uri :confname ident}]
                                                              user-services
                                                              :root)
                                              first)]
                              (response (ensure-name (ensure-token service))))))
                    (PUT "/" {doc :body}
                         (locking services
                            (let [uri (or (get doc "root") (get-in config [:services (real-id ident)]))
                                  current (first (get-where services [:= :root uri]))]
                              (if current
                                (update services (:id current) doc)
                                (try
                                  (let [token (or (get doc "token") (register-for {:root uri}))] ;; New record. Ensure valid.
                                    (create-new services (-> doc (assoc :root uri :token token) (dissoc "root" "token"))))
                                  (catch Exception e {:status 400 :body {:message (str "bad service definition: " e)}}))))))))))

(defn- build-api-session-routes [router]
  (-> (routes
        (POST "/"
              {sess :session}
              (issue-session (:config router) (:secrets router) (:identity sess))))
      (wrap-session {:store (:session-store router)})))

(defn- api-v1 [router]
  (let [hist-routes (build-hist-routes router)
        step-routes (build-step-routes router)
        project-routes (build-project-routes router)
        service-routes (build-service-routes router)
        api-session-routes (build-api-session-routes router)]
    (routes ;; put them all together
            (context "/sessions" [] api-session-routes)
            (-> (routes 
                  (context "/histories" [] hist-routes)
                  (context "/services" [] service-routes)
                  (context "/steps" [] step-routes)
                  (context "/projects" [] project-routes))
                (wrap-api-auth router))
            (route/not-found {:message "Not found"}))))

(defn wrap-bind-user
  [handler]
  (fn [request]
    (let [user (:identity (friend/current-authentication request))]
      (info "for" (:uri request) "user =" user)
      (binding [staircase.resources/context {:user user}]
        (handler request)))))

(def friendly-hosts [ #"http://localhost:"
                     #"http://[^/]*labs.intermine.org"
                     #"http://intermine.github.io"
                     #"http://alexkalderimis.github.io"])

(defn allowed-origins
  [audience]
  (if audience (conj friendly-hosts (re-pattern audience)) friendly-hosts))

(defrecord Router [session-store
                   asset-pipeline
                   config
                   secrets
                   services
                   histories
                   steps
                   handler]

  component/Lifecycle

  (start [this]
    (info "Starting steps app at" (:audience config))
    (let [persona (partial persona-workflow (:audience config))
          auth-conf {:credential-fn credential-fn
                     :workflows [persona anonymous-workflow]}
          app-routes (build-app-routes this)
          v1 (context "/api/v1" [] (api-v1 this))
          handler (routes
                      (-> (handler/api v1) wrap-json-body)
                      (-> app-routes
                          handler/api
                          (friend/authenticate auth-conf)
                          (wrap-session {:store session-store})
                          (wrap-cookies)
                          asset-pipeline
                          pm/wrap-persona-resources))]
      (assoc this :handler (-> handler
                               wrap-restful-format
                               (wrap-cors :access-control-allow-origin (allowed-origins (:audience config)))))))

  (stop [this] this))

(defn new-router [] (map->Router {}))