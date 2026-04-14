FROM sergeit215/phenoscript-docker:latest

# All tools are inherited from the base image:
#   phenospy (yphs2owl, owl2text), Apache Jena (shacl, riot, update),
#   ROBOT, Materializer (whelk reasoner)
#
# The entrypoint.sh from the base image is used as-is for the convert step.
# The materialize step overrides ENTRYPOINT at runtime via --entrypoint bash.
