# dbt POV Model Cost Savings

A specialized dbt package designed to help dbt Labs calculate potential cost savings customers may realize from switching to the dbt Fusion engine's state-aware orchestration. 

This package tracks model execution patterns and costs to analyze the efficiency gains possible with Fusion's intelligent scheduling and resource optimization.

> **Important**: This package is designed specifically for dbt Labs' internal proof-of-value of fusion cost savings potential. While the community is free to use it, dbt Labs support is limited to this specific purpose. For general model cost tracking and monitoring, we recommend using community or vendor-supported packages (see [Alternative Solutions](#alternative-solutions) below).

## 📚 Documentation Index

- **[Setup Guide](SETUP.md)** - Installation, configuration, and troubleshooting
- **[About This Package](ABOUT.md)** - Tables, schemas, and generated models
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to this project

## Purpose

This package enables analysis of:
- **Model execution patterns** and their associated costs
- **Resource utilization** across different scheduling approaches  
- **Potential savings** from fusion's state-aware orchestration
- **Historical cost trends** to project fusion benefits

## Alternative Solutions

For general model cost tracking and data observability beyond fusion cost analysis, we recommend these community and vendor-supported packages:

### Community Packages

- **[Elementary dbt-data-reliability](https://github.com/elementary-data/dbt-data-reliability)**: Comprehensive data observability package with anomaly detection, schema monitoring, and cost tracking capabilities
- **[select.dev packages](https://select.dev/)**: Professional data observability and cost monitoring solutions
- **[dbt-artifacts](https://github.com/brooklyn-data/dbt_artifacts)

### Why Use Alternatives?

While this package is freely available, it's specifically designed for dbt Labs' fusion cost analysis. For broader data observability needs, the packages above offer:

- **Dedicated support** from their respective teams
- **Regular updates** and feature development
- **Comprehensive documentation** and community resources
- **Production-ready** monitoring and alerting capabilities
- **Integration** with popular data observability platforms

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

**Limited Support Scope**: This package is designed specifically for dbt Labs' fusion cost analysis. Support is limited to issues related to this specific purpose.

For general questions and community support:
- Join the [dbt Community Slack](http://community.getdbt.com/)
- Read more on the [dbt Community Discourse](https://discourse.getdbt.com)

For fusion cost analysis issues:
- Open an issue on GitHub for bugs or feature requests related to fusion cost calculations

For general model cost tracking and data observability:
- Consider using [Elementary](https://github.com/elementary-data/dbt-data-reliability) or [select.dev](https://select.dev/) packages with dedicated support teams
