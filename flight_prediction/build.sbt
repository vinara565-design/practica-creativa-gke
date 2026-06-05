name := "flight_prediction"
version := "0.1"
scalaVersion := "2.13.15"
val sparkVersion = "4.1.1"
mainClass in Compile := Some("es.upm.dit.ging.predictor.MakePrediction")
resolvers ++= Seq(
  "apache-snapshots" at "https://repository.apache.org/snapshots/"
)
libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion,
  "org.apache.spark" %% "spark-sql" % sparkVersion,
  "org.apache.spark" %% "spark-mllib" % sparkVersion,
  "org.apache.spark" %% "spark-streaming" % sparkVersion,
  "org.apache.spark" %% "spark-hive" % sparkVersion,
  "org.apache.spark" %% "spark-sql-kafka-0-10" % sparkVersion,
  "org.mongodb.spark" %% "mongo-spark-connector" % "10.4.1",
  "com.datastax.spark" %% "spark-cassandra-connector" % "3.5.1"
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", "versions", _, "module-info.class") => MergeStrategy.discard
  case PathList("META-INF", "io.netty.versions.properties") => MergeStrategy.first
  case PathList("META-INF", "proguard", _*) => MergeStrategy.first
  case PathList("META-INF", "org", "apache", "logging", _*) => MergeStrategy.first
  case PathList("META-INF", "native-image", _*) => MergeStrategy.first
  case PathList("META-INF", "license", _*) => MergeStrategy.first
  case PathList("javax", "jdo", _*) => MergeStrategy.first
  case PathList("org", "apache", "hadoop", "hive", _*) => MergeStrategy.first
  case PathList("org", "apache", "commons", "logging", _*) => MergeStrategy.first
  case PathList("mozilla", _*) => MergeStrategy.first
  case PathList("plugin.xml") => MergeStrategy.first
  case PathList("scala", "collection", "compat", _*) => MergeStrategy.first
  case PathList("module-info.class") => MergeStrategy.discard
  case x =>
    val oldStrategy = (assembly / assemblyMergeStrategy).value
    oldStrategy(x)
}
