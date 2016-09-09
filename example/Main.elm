module Main exposing (main)

import Html exposing (Html)
import Html.App
import Html.Attributes as HA
import Benchmark
import Process
import Task
import Numeral


type alias Model =
    { results : List Benchmark.Result
    , done : Bool
    , platform : Maybe String
    }


type Msg
    = Started ()
    | Event Benchmark.Event


main =
    Html.App.program
        { init = init
        , update = update
        , view = view
        , subscriptions = always (Benchmark.events Event)
        }


init : ( Model, Cmd Msg )
init =
    ( Model [] False Nothing
    , Task.perform (\_ -> Debug.crash "Benchmark.runTask failed")
        Started
        (Benchmark.runTask
            [ suite1
            , suite2
            ]
        )
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Event event ->
            case event of
                Benchmark.Start { platform } ->
                    { model | platform = Just platform } ! []

                Benchmark.Cycle result ->
                    { model | results = model.results ++ [ result ] } ! []

                Benchmark.Complete result ->
                    model ! []

                Benchmark.Finished ->
                    { model | done = True } ! []

                Benchmark.BenchError error ->
                    Debug.crash "benchmark error" error

        _ ->
            model ! []


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.h1 [] [ Html.text "Benchmark results" ]
        , viewPlatform model.platform
        , viewResults model
        , viewStatus model
        ]


viewPlatform platformMaybe =
    case platformMaybe of
        Just platform ->
            Html.div []
                [ Html.h2 [] [ Html.text "Platform" ]
                , Html.p [] [ Html.text platform ]
                ]

        Nothing ->
            Html.text ""


viewStatus : Model -> Html Msg
viewStatus model =
    Html.p []
        [ Html.text
            (if model.done then
                "Done"
             else
                "running ..."
            )
        ]


viewResults : Model -> Html Msg
viewResults model =
    let
        viewResult e =
            let
                stats =
                    Benchmark.getStats e.samples

                meanFreq =
                    1 / stats.mean
            in
                Html.tr []
                    [ Html.td [] [ Html.text e.suite ]
                    , Html.td [] [ Html.text e.benchmark ]
                    , Html.td [ HA.class "numeric" ] [ Html.text (Numeral.format "0" meanFreq) ]
                    , Html.td [ HA.class "numeric" ] [ Html.text (Numeral.format "0.0" stats.relativeMarginOfError) ]
                    , Html.td [ HA.class "numeric" ] [ Html.text (toString stats.size) ]
                    ]

        th str =
            Html.th [] [ Html.text str ]
    in
        Html.table []
            [ Html.thead []
                (List.map th [ "suite", "benchmark", "freq", "error%", "samples" ])
            , Html.tbody []
                (List.map viewResult model.results)
            ]



-- benchmarks and their suites


options =
    let
        defaults =
            Benchmark.defaultOptions
    in
        { defaults | maxTime = 2 }


suite1 : Benchmark.Suite
suite1 =
    Benchmark.suiteWithOptions options
        "suite1"
        [ Benchmark.bench "fn1" testfn1
        , Benchmark.bench "fn2" testfn2
        , Benchmark.bench "fn1 again" testfn1
        ]


suite2 : Benchmark.Suite
suite2 =
    Benchmark.suiteWithOptions options
        "suite2"
        [ Benchmark.bench "fn3" testfn3
        , Benchmark.bench "fn3 again" testfn3
        , Benchmark.bench "fn3 another" testfn3
        ]


testdata : List Int
testdata =
    [1..10000]


testfn1 : () -> List Int
testfn1 =
    \() -> List.map ((+) 1) testdata


testfn2 : () -> List Int
testfn2 =
    \() -> List.map ((*) 7) testdata


testfn3 : () -> List Int
testfn3 =
    \() -> List.map (\i -> i // 42) testdata
